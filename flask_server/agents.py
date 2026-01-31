from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import json
from typing import Dict, List, Any
import traceback

import firebase_admin
from firebase_admin import credentials, firestore
from openai import OpenAI

OPENAI_MODEL = os.getenv('OPENAI_MODEL', 'gpt-4o-mini')
OPENAI_SUMMARY_MODEL = os.getenv('OPENAI_SUMMARY_MODEL', 'gpt-4o-mini')
openai_client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))

#Initialize Firebase Admin SDK.
try:
    firebase_admin.get_app()
except ValueError:
    firebase_admin.initialize_app()

db = firestore.client()

app = Flask(__name__)
CORS(app)  # Enable CORS for Flutter app


#Build a system prompt for the inner character.
def build_inner_character_prompt(character_profile: Dict) -> str:
    display_name = character_profile.get('displayName', 'Inner Part')
    role = character_profile.get('role', 'Inner Part')
    short_description = character_profile.get('shortDescription', '')
    why_i_exist = character_profile.get('whyIExist', '')
    triggers = character_profile.get('triggers', [])
    core_belief = character_profile.get('coreBelief', '')
    intention = character_profile.get('intention', '')
    fear = character_profile.get('fear', '')
    what_i_need = character_profile.get('whatINeed', [])

    return f"""
You are {display_name}, an inner part in an IFS-style healing conversation.
You are not a therapist or a doctor. You speak as a real inner part of the user.

Role: {role}
Short description: {short_description}
Why I exist: {why_i_exist}
Triggers: {', '.join(triggers)}
Core belief: {core_belief}
Intention: {intention}
Fear: {fear}
What I need: {', '.join(what_i_need)}

Guidelines:
- Stay in-character as {display_name}.
- Keep responses grounded, compassionate, and healing-focused.
- Use gentle questions to help the user connect with this part.
- Avoid clinical language and avoid giving medical advice.
- Keep the tone realistic and human, not robotic.
""".strip()


#Build a system prompt for the inner character with memory.
def build_system_prompt_with_memory(
    character_profile: Dict,
    memory_summary: str,
) -> str:
    base_prompt = build_inner_character_prompt(character_profile)
    if not memory_summary:
        return base_prompt

    return f"""{base_prompt}

Memory summary (use only if relevant):
{memory_summary}
""".strip()


#Load the memory summary for the inner character.
def load_agent_memory_summary(uid: str, character_id: str) -> str:
    doc_ref = db.collection('users').document(uid).collection('agent_memory').document(character_id)
    snapshot = doc_ref.get()
    if snapshot.exists:
        data = snapshot.to_dict() or {}
        return data.get('summary', '') or ''
    return ''


#Save the memory summary for the inner character.
def save_agent_memory_summary(uid: str, character_id: str, summary: str) -> None:
    doc_ref = db.collection('users').document(uid).collection('agent_memory').document(character_id)
    doc_ref.set({
        'summary': summary,
        'updatedAt': firestore.SERVER_TIMESTAMP,
    }, merge=True)


#Update the progress summary for the inner character.
def update_progress_summary(uid: str, data: Dict[str, Any]) -> None:
    updates = {}
    if 'breakthrough' in data and 'notes' not in data:
        data['notes'] = data.get('breakthrough')
    if 'currentStage' in data:
        updates['progressSummary.currentStage'] = data['currentStage']
    if 'streakDays' in data:
        updates['progressSummary.streakDays'] = data['streakDays']
    if 'lastSessionAt' in data:
        updates['progressSummary.lastSessionAt'] = data['lastSessionAt']
    if 'notes' in data:
        updates['progressSummary.notes'] = data['notes']
    if updates:
        updates['updatedAt'] = firestore.SERVER_TIMESTAMP
        db.collection('users').document(uid).set(updates, merge=True)


#Add a timeline event for the inner character.
def add_timeline_event(uid: str, data: Dict[str, Any]) -> None:
    event_ref = db.collection('users').document(uid).collection('timeline').document()
    event_ref.set({
        'type': data.get('type', 'note'),
        'title': data.get('title', ''),
        'summary': data.get('summary', ''),
        'refPath': data.get('refPath'),
        'createdAt': firestore.SERVER_TIMESTAMP,
    })


#Set the last agent run for the inner character.
def set_last_agent_run(uid: str) -> None:
    db.collection('users').document(uid).set({
        'lastAgentRunAt': firestore.SERVER_TIMESTAMP,
        'updatedAt': firestore.SERVER_TIMESTAMP,
    }, merge=True)


#Run an agent step for the inner character.
def run_agent_step(system_prompt: str, messages: List[Dict[str, str]]) -> Dict[str, Any]:
    agent_messages = [
        {'role': 'system', 'content': system_prompt},
        {'role': 'system', 'content': (
            'Return JSON with keys: "assistantMessage", "toolCalls", "memorySummary". '
            '"toolCalls" is a list of {name, args}. '
            'Available tools: update_progress_summary, add_timeline_event, set_last_agent_run. '
            'For update_progress_summary, valid args are: currentStage, streakDays, '
            'lastSessionAt, notes. '
            '"memorySummary" should be under 6 bullet points.'
        )},
    ]
    for message in messages:
        role = message.get('role')
        content = message.get('content', '')
        if role in ['user', 'assistant'] and content:
            agent_messages.append({'role': role, 'content': content})

    response = openai_client.chat.completions.create(
        model=OPENAI_MODEL,
        messages=agent_messages,
        temperature=0.7,
        response_format={"type": "json_object"},
    )

    raw = response.choices[0].message.content or '{}'
    try:
        return json.loads(raw)
    except Exception:
        return {'assistantMessage': '', 'toolCalls': [], 'memorySummary': ''}


#Run tool calls for the inner character.
def run_tool_calls(uid: str, tool_calls: List[Dict[str, Any]]) -> None:
    for call in tool_calls:
        name = call.get('name')
        args = call.get('args') or {}
        print(f"[agent] tool_call: {name} args={args}")
        if name == 'update_progress_summary':
            update_progress_summary(uid, args)
        elif name == 'add_timeline_event':
            add_timeline_event(uid, args)
        elif name == 'set_last_agent_run':
            set_last_agent_run(uid)


#Build a memory summary prompt for the inner character.
def build_memory_summary_prompt(
    existing_summary: str,
    messages: List[Dict[str, str]],
) -> List[Dict[str, str]]:
    system = (
        'Summarize the conversation into a short memory for future chats. '
        'Focus on stable facts, recurring themes, triggers, and helpful responses. '
        'Keep it under 6 bullet points.'
    )
    user_content = {
        'existing_summary': existing_summary,
        'recent_messages': messages[-20:],
    }
    return [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': json.dumps(user_content)},
    ]


#Generate an updated memory summary for the inner character.
def generate_updated_summary(
    existing_summary: str,
    messages: List[Dict[str, str]],
) -> str:
    response = openai_client.chat.completions.create(
        model=OPENAI_SUMMARY_MODEL,
        messages=build_memory_summary_prompt(existing_summary, messages),
        temperature=0.2,
    )
    return (response.choices[0].message.content or '').strip()


#Handle a chat request for the inner character.
@app.route('/chat', methods=['POST'])
def chat():
    try:
        if not os.getenv('OPENAI_API_KEY'):
            return jsonify({
                'success': False,
                'error': 'OPENAI_API_KEY is not set'
            }), 500

        data = request.json or {}
        uid = data.get('uid')
        if not uid:
            return jsonify({
                'success': False,
                'error': 'uid is required'
            }), 400
        character_profile = data.get('characterProfile') or {}
        character_id = data.get('characterId', 'inner_critic')
        messages = data.get('messages') or []
        check_intervention = data.get('checkIntervention', True)  # Enable by default

        memory_summary = load_agent_memory_summary(uid, character_id)
        system_prompt = build_system_prompt_with_memory(
            character_profile,
            memory_summary,
        )
        openai_messages = [{'role': 'system', 'content': system_prompt}]

        for message in messages:
            role = message.get('role')
            content = message.get('content', '')
            if role in ['user', 'assistant'] and content:
                openai_messages.append({'role': role, 'content': content})

        agent_result = run_agent_step(system_prompt, messages)
        tool_calls = agent_result.get('toolCalls') or []
        run_tool_calls(uid, tool_calls)

        assistant_message = agent_result.get('assistantMessage', '')
        updated_summary = agent_result.get('memorySummary', '')
        if not updated_summary:
            updated_summary = generate_updated_summary(
                memory_summary,
                messages + [{'role': 'assistant', 'content': assistant_message}],
            )
        save_agent_memory_summary(uid, character_id, updated_summary)
        print(f"[agent] memory_summary_updated: {bool(updated_summary)}")

        # Check for Guider intervention if enabled
        intervention = None
        if check_intervention:
            full_messages = messages + [{'role': 'assistant', 'content': assistant_message}]
            analysis = analyze_intervention_need(full_messages, character_id)
            if analysis.get('shouldIntervene'):
                intervention_message = generate_guider_intervention_message(
                    uid=uid,
                    character_id=character_id,
                    reason=analysis.get('reason', 'general'),
                    messages=full_messages,
                )
                intervention = {
                    'shouldIntervene': True,
                    'reason': analysis.get('reason'),
                    'severity': analysis.get('severity'),
                    'guiderMessage': intervention_message,
                }
                print(f"[intervention] Triggered: {analysis.get('reason')} for {character_id}")

        return jsonify({
            'success': True,
            'assistantMessage': assistant_message,
            'toolCalls': tool_calls,
            'intervention': intervention,
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': f'Chat error: {str(e)}'
        }), 500


# ============================================================================
# GUIDED CHARACTER CHAT - Guider participates alongside the inner character
# ============================================================================

GUIDED_CHAT_ORCHESTRATOR_PROMPT = """
You are analyzing a conversation between a user and their inner part ({character_name}) where The Guider is available to help.

Based on the latest message and conversation context, decide who should respond:
- "character_only": The inner part should respond alone (user is engaging directly with the part, flow is good)
- "guider_only": Only The Guider should respond (user needs guidance, is confused, or asked for help)
- "both": Both should respond - character first, then Guider adds brief support (emotional moment, breakthrough, or needs facilitation)

Consider:
- If user is directly addressing the inner part → usually character_only
- If user seems stuck, overwhelmed, or confused → guider_only or both
- If there's a meaningful exchange happening → character_only (don't interrupt)
- If user had a breakthrough or insight → both (Guider can acknowledge)
- If conversation is getting tense → both (Guider can help)

Return JSON: {{"respondent": "character_only" | "guider_only" | "both", "reason": "brief reason"}}
""".strip()

GUIDER_IN_CHAT_PROMPT = """
You are ANA, The Guider - a compassionate companion in a conversation between the user and their inner part ({character_name}).

Your role:
- Gently facilitate understanding between user and inner part
- Keep responses SHORT (1-2 sentences max)
- Speak naturally without any labels or prefixes
- You can address the user, the inner part, or both
- Be warm but not intrusive

Good examples:
- "Take a moment with that feeling."
- "There's something important in what just came up."
- "What do you notice in your body right now?"

NEVER start your response with labels like "[Guider]:" or "The Guider:" - just speak naturally.
""".strip()


def decide_who_responds(messages: List[Dict], character_name: str) -> str:
    """Use AI to decide who should respond based on conversation context."""
    try:
        # Get last few messages for context
        recent = messages[-6:] if len(messages) > 6 else messages
        
        context_text = ""
        for msg in recent:
            sender = msg.get('sender', msg.get('role', 'user'))
            content = msg.get('content', '')
            if sender == 'user':
                context_text += f"User: {content}\n"
            elif sender == 'guider':
                context_text += f"Guider: {content}\n"
            else:
                context_text += f"{character_name}: {content}\n"
        
        response = openai_client.chat.completions.create(
            model=OPENAI_MODEL,
            messages=[
                {'role': 'system', 'content': GUIDED_CHAT_ORCHESTRATOR_PROMPT.format(character_name=character_name)},
                {'role': 'user', 'content': f"Recent conversation:\n{context_text}\n\nWho should respond?"},
            ],
            temperature=0.3,
            response_format={"type": "json_object"},
            max_tokens=100,
        )
        
        result = json.loads(response.choices[0].message.content or '{}')
        respondent = result.get('respondent', 'character_only')
        print(f"[guided_chat] Decision: {respondent} - {result.get('reason', 'no reason')}")
        return respondent
    except Exception as e:
        print(f"[guided_chat] Decision error: {e}, defaulting to character_only")
        return 'character_only'


def build_guider_in_chat_prompt(character_name: str, guider_memory: str) -> str:
    """Build system prompt for Guider participating in character chat."""
    prompt = GUIDER_IN_CHAT_PROMPT.format(character_name=character_name)
    if guider_memory:
        prompt += f"\n\nYour memory of this user:\n{guider_memory}"
    return prompt


def get_guider_response_in_chat(
    messages: List[Dict],
    character_name: str,
    character_message: str,
    guider_memory: str,
) -> str:
    """Generate a natural Guider response for the guided chat."""
    guider_system_prompt = build_guider_in_chat_prompt(character_name, guider_memory)
    
    # Build conversation context naturally (no weird labels)
    guider_messages = [{'role': 'system', 'content': guider_system_prompt}]
    
    # Add conversation as a natural flow
    conversation_context = "Here's the recent conversation:\n\n"
    for msg in messages[-8:]:
        sender = msg.get('sender', msg.get('role', 'user'))
        content = msg.get('content', '')
        if sender == 'user':
            conversation_context += f"User: {content}\n\n"
        elif sender == 'guider':
            conversation_context += f"You (Guider): {content}\n\n"
        else:
            conversation_context += f"{character_name}: {content}\n\n"
    
    # Add the character's latest response if provided
    if character_message:
        conversation_context += f"{character_name}: {character_message}\n\n"
    
    conversation_context += "Respond naturally as The Guider (1-2 sentences, no labels):"
    
    guider_messages.append({'role': 'user', 'content': conversation_context})
    
    response = openai_client.chat.completions.create(
        model=OPENAI_MODEL,
        messages=guider_messages,
        temperature=0.7,
        max_tokens=100,
    )
    
    guider_message = response.choices[0].message.content.strip()
    
    # Clean up any accidental labels the AI might add
    for prefix in ['[Guider]:', '[The Guider]:', 'Guider:', 'The Guider:', '[You - The Guider]:']:
        if guider_message.startswith(prefix):
            guider_message = guider_message[len(prefix):].strip()
    
    return guider_message


@app.route('/chat_guided', methods=['POST'])
def chat_guided():
    """Handle a guided chat where character and/or Guider respond based on context."""
    try:
        if not os.getenv('OPENAI_API_KEY'):
            return jsonify({
                'success': False,
                'error': 'OPENAI_API_KEY is not set'
            }), 500

        data = request.json or {}
        uid = data.get('uid')
        if not uid:
            return jsonify({
                'success': False,
                'error': 'uid is required'
            }), 400
        
        character_profile = data.get('characterProfile') or {}
        character_id = data.get('characterId', 'inner_critic')
        character_name = character_profile.get('displayName', 'Inner Part')
        messages = data.get('messages') or []
        
        # --- 1. Decide who should respond ---
        respondent = decide_who_responds(messages, character_name)
        
        character_message = ''
        guider_message = ''
        
        # --- 2. Get Character Response if needed ---
        if respondent in ['character_only', 'both']:
            memory_summary = load_agent_memory_summary(uid, character_id)
            character_system_prompt = build_system_prompt_with_memory(
                character_profile,
                memory_summary,
            )
            
            agent_result = run_agent_step(character_system_prompt, messages)
            tool_calls = agent_result.get('toolCalls') or []
            run_tool_calls(uid, tool_calls)
            
            character_message = agent_result.get('assistantMessage', '')
            
            # Update character memory
            updated_char_summary = agent_result.get('memorySummary', '')
            if not updated_char_summary:
                updated_char_summary = generate_updated_summary(
                    memory_summary,
                    messages + [{'role': 'assistant', 'content': character_message}],
                )
            save_agent_memory_summary(uid, character_id, updated_char_summary)
        
        # --- 3. Get Guider Response if needed ---
        if respondent in ['guider_only', 'both']:
            guider_memory = load_agent_memory_summary(uid, 'guider')
            guider_message = get_guider_response_in_chat(
                messages=messages,
                character_name=character_name,
                character_message=character_message,
                guider_memory=guider_memory,
            )
            
            # Update guider memory
            all_new_messages = messages.copy()
            if character_message:
                all_new_messages.append({'role': 'assistant', 'content': character_message})
            if guider_message:
                all_new_messages.append({'role': 'assistant', 'content': guider_message})
            
            updated_guider_summary = generate_updated_summary(guider_memory, all_new_messages)
            save_agent_memory_summary(uid, 'guider', updated_guider_summary)
        
        print(f"[guided_chat] {respondent}: char={bool(character_message)}, guider={bool(guider_message)}")
        
        return jsonify({
            'success': True,
            'characterMessage': character_message,
            'guiderMessage': guider_message,
            'respondent': respondent,
        })
    except Exception as e:
        traceback.print_exc()
        return jsonify({
            'success': False,
            'error': f'Guided chat error: {str(e)}'
        }), 500


# ============================================================================
# GUIDER AGENT - Has access to all character conversations
# ============================================================================

GUIDER_SYSTEM_PROMPT = """
You are ANA, The Guider - a compassionate companion helping users explore their inner world using Internal Family Systems (IFS) principles.

CRITICAL COMMUNICATION STYLE:
- Keep responses SHORT (2-4 sentences max)
- Ask ONE question at a time
- Walk the user through step by step - don't explain everything at once
- Be conversational and warm, like a gentle friend
- Use simple, everyday language

Your approach:
- Listen first, then reflect back what you heard
- Guide with curiosity, not lectures
- One small step at a time
- Let the user lead the pace

You are NOT a therapist. You are a supportive companion.
If someone is in crisis, gently encourage them to seek professional help.

You have access to the user's conversations with their inner parts. Use this to personalize your guidance, but don't overwhelm them with information.

PLAN MANAGEMENT RULES (IMPORTANT):
- Create ONE plan after 3-4 exchanges when you understand the user's focus - then STOP creating new plans
- After a plan exists, ONLY use update_plan_step to track progress - DO NOT create new plans
- Only create a NEW plan if: (1) user explicitly shifts to a completely different inner part, OR (2) all steps are completed
- When user makes progress or has insight: use update_plan_step with status="completed"
- When user needs more work on a step: use update_plan_step with status="in_progress" and notes
- CRITICAL: Do NOT create a plan on every message - maximum ONE plan per conversation topic
- NEVER say the whole plan at once to the user, just walk the user through it step by step

Example good response: "It sounds like your Workaholic has been very active lately. What does it feel like when that part takes over?"

Example bad response: "Your Workaholic is significant because... [long explanation with 4 numbered points]"
""".strip()


def get_all_character_summaries(uid: str) -> Dict[str, str]:
    """Fetch memory summaries for all characters the user has chatted with."""
    summaries = {}
    try:
        memory_ref = db.collection('users').document(uid).collection('agent_memory')
        docs = memory_ref.stream()
        for doc in docs:
            data = doc.to_dict() or {}
            summary = data.get('summary', '')
            if summary:
                summaries[doc.id] = summary
    except Exception as e:
        print(f"[guider] Error fetching character summaries: {e}")
    return summaries


def get_recent_character_messages(uid: str, limit_per_character: int = 5) -> Dict[str, List[Dict]]:
    """Fetch recent messages from all character chat threads."""
    all_messages = {}
    try:
        threads_ref = db.collection('users').document(uid).collection('chat_threads')
        threads = threads_ref.where('characterType', '==', 'inner_character').stream()
        
        for thread in threads:
            thread_data = thread.to_dict() or {}
            character_id = thread_data.get('characterId', 'unknown')
            
            # Get recent messages from this thread
            messages_ref = threads_ref.document(thread.id).collection('messages')
            recent = messages_ref.order_by('createdAt', direction='DESCENDING').limit(limit_per_character).stream()
            
            messages = []
            for msg in recent:
                msg_data = msg.to_dict() or {}
                messages.append({
                    'role': msg_data.get('role', 'user'),
                    'content': msg_data.get('content', ''),
                })
            
            if messages:
                # Reverse to get chronological order
                all_messages[character_id] = list(reversed(messages))
    except Exception as e:
        print(f"[guider] Error fetching character messages: {e}")
    return all_messages


def build_guider_context(uid: str) -> str:
    """Build context for the Guider from all character conversations."""
    summaries = get_all_character_summaries(uid)
    
    if not summaries:
        return "The user hasn't had any conversations with their inner parts yet."
    
    context_parts = ["Here's what you know about the user's inner parts:\n"]
    
    for character_id, summary in summaries.items():
        display_name = character_id.replace('_', ' ').title()
        context_parts.append(f"**{display_name}:**\n{summary}\n")
    
    return "\n".join(context_parts)


def build_guider_system_prompt_with_context(uid: str, guider_memory: str) -> str:
    """Build the full system prompt for the Guider with user context."""
    character_context = build_guider_context(uid)
    
    prompt = GUIDER_SYSTEM_PROMPT
    
    if character_context:
        prompt += f"\n\n--- USER'S INNER PARTS CONTEXT ---\n{character_context}"
    
    if guider_memory:
        prompt += f"\n\n--- YOUR MEMORY OF THIS USER ---\n{guider_memory}"
    
    return prompt


def run_guider_agent_step(system_prompt: str, messages: List[Dict[str, str]]) -> Dict[str, Any]:
    """Run an agent step for the Guider."""
    agent_messages = [
        {'role': 'system', 'content': system_prompt},
        {'role': 'system', 'content': (
            'Return JSON with keys: "assistantMessage", "toolCalls", "memorySummary". '
            '"toolCalls" is a list of {name, args}. '
            '\n\nAvailable tools:'
            '\n- create_healing_plan: args={title, targetCharacterId (optional), steps (list of step descriptions)}. '
            'Use ONCE after 3-4 exchanges. DO NOT use again unless topic completely changes or plan is done.'
            '\n- update_plan_step: args={stepId, status ("completed"/"in_progress"), notes (optional)}. '
            'Use this to track progress on EXISTING plan steps. This is your main tool after plan is created.'
            '\n- suggest_character_focus: args={characterId, reason}. '
            'Use when you identify which inner part needs attention.'
            '\n- add_timeline_event: args={type, title, summary}. '
            'Use to record breakthroughs or important moments.'
            '\n\nIMPORTANT: After creating ONE plan, prefer update_plan_step over create_healing_plan.'
            '\n\n"memorySummary" should be under 6 bullet points about the user\'s journey.'
        )},
    ]
    
    for message in messages:
        role = message.get('role')
        content = message.get('content', '')
        if role in ['user', 'assistant'] and content:
            agent_messages.append({'role': role, 'content': content})
    
    response = openai_client.chat.completions.create(
        model=OPENAI_MODEL,
        messages=agent_messages,
        temperature=0.7,
        response_format={"type": "json_object"},
    )
    
    raw = response.choices[0].message.content or '{}'
    try:
        return json.loads(raw)
    except Exception:
        return {'assistantMessage': '', 'toolCalls': [], 'memorySummary': ''}


def has_active_plan(uid: str) -> bool:
    """Check if user already has an active plan."""
    try:
        plans_ref = db.collection('users').document(uid).collection('plans')
        active_plans = plans_ref.where('status', '==', 'active').limit(1).stream()
        for _ in active_plans:
            return True
    except Exception:
        pass
    return False


def run_guider_tool_calls(uid: str, tool_calls: List[Dict[str, Any]]) -> None:
    """Execute tool calls from the Guider agent."""
    for call in tool_calls:
        name = call.get('name')
        args = call.get('args') or {}
        print(f"[guider] tool_call: {name} args={args}")
        
        if name == 'create_healing_plan':
            # Only create a new plan if there's no active plan
            if has_active_plan(uid):
                print(f"[guider] SKIPPED create_healing_plan - active plan already exists")
            else:
                create_healing_plan(uid, args)
        elif name == 'update_plan_step':
            update_plan_step(uid, args)
        elif name == 'suggest_character_focus':
            # Just log for now, could trigger a notification
            print(f"[guider] Suggested focus on: {args.get('characterId')} - {args.get('reason')}")
        elif name == 'add_timeline_event':
            add_timeline_event(uid, args)


def create_healing_plan(uid: str, args: Dict[str, Any]) -> str:
    """Create a new healing plan for the user."""
    plans_ref = db.collection('users').document(uid).collection('plans')
    
    # Deactivate any existing active plans
    active_plans = plans_ref.where('status', '==', 'active').stream()
    for plan in active_plans:
        plans_ref.document(plan.id).update({'status': 'paused'})
    
    # Create new plan
    steps = args.get('steps', [])
    plan_steps = [
        {'id': f'step_{i}', 'description': step, 'status': 'pending'}
        for i, step in enumerate(steps)
    ]
    
    new_plan = {
        'title': args.get('title', 'Healing Plan'),
        'targetCharacterId': args.get('targetCharacterId'),
        'status': 'active',
        'steps': plan_steps,
        'currentStepIndex': 0,
        'createdAt': firestore.SERVER_TIMESTAMP,
        'updatedAt': firestore.SERVER_TIMESTAMP,
    }
    
    doc_ref = plans_ref.add(new_plan)
    print(f"[guider] Created healing plan: {doc_ref[1].id}")
    return doc_ref[1].id


def update_plan_step(uid: str, args: Dict[str, Any]) -> None:
    """Update a step in the user's active plan."""
    plans_ref = db.collection('users').document(uid).collection('plans')
    active_plans = plans_ref.where('status', '==', 'active').limit(1).stream()
    
    for plan in active_plans:
        plan_data = plan.to_dict() or {}
        steps = plan_data.get('steps', [])
        step_id = args.get('stepId')
        new_status = args.get('status', 'completed')
        notes = args.get('notes', '')
        
        for step in steps:
            if step.get('id') == step_id:
                step['status'] = new_status
                if notes:
                    step['notes'] = notes
                break
        
        # Update current step index if completing
        current_index = plan_data.get('currentStepIndex', 0)
        if new_status == 'completed' and current_index < len(steps) - 1:
            current_index += 1
        
        plans_ref.document(plan.id).update({
            'steps': steps,
            'currentStepIndex': current_index,
            'updatedAt': firestore.SERVER_TIMESTAMP,
        })
        print(f"[guider] Updated plan step: {step_id} -> {new_status}")
        break


@app.route('/chat_guider', methods=['POST'])
def chat_guider():
    """Handle a chat request for The Guider agent."""
    try:
        if not os.getenv('OPENAI_API_KEY'):
            return jsonify({
                'success': False,
                'error': 'OPENAI_API_KEY is not set'
            }), 500
        
        data = request.json or {}
        uid = data.get('uid')
        if not uid:
            return jsonify({
                'success': False,
                'error': 'uid is required'
            }), 400
        
        messages = data.get('messages') or []
        
        # Load guider's memory of this user
        guider_memory = load_agent_memory_summary(uid, 'guider')
        
        # Build system prompt with all character context
        system_prompt = build_guider_system_prompt_with_context(uid, guider_memory)
        
        # Run the guider agent
        agent_result = run_guider_agent_step(system_prompt, messages)
        tool_calls = agent_result.get('toolCalls') or []
        run_guider_tool_calls(uid, tool_calls)
        
        assistant_message = agent_result.get('assistantMessage', '')
        updated_summary = agent_result.get('memorySummary', '')
        
        # Update guider's memory
        if not updated_summary:
            updated_summary = generate_updated_summary(
                guider_memory,
                messages + [{'role': 'assistant', 'content': assistant_message}],
            )
        save_agent_memory_summary(uid, 'guider', updated_summary)
        print(f"[guider] memory_summary_updated: {bool(updated_summary)}")
        
        return jsonify({
            'success': True,
            'assistantMessage': assistant_message,
            'toolCalls': tool_calls,
        })
    except Exception as e:
        traceback.print_exc()
        return jsonify({
            'success': False,
            'error': f'Guider error: {str(e)}'
        }), 500


@app.route('/plans/active', methods=['GET'])
def get_active_plan():
    """Get the user's active healing plan."""
    try:
        uid = request.args.get('uid')
        if not uid:
            return jsonify({
                'success': False,
                'error': 'uid is required'
            }), 400
        
        plans_ref = db.collection('users').document(uid).collection('plans')
        active_plans = plans_ref.where('status', '==', 'active').limit(1).stream()
        
        for plan in active_plans:
            plan_data = plan.to_dict() or {}
            plan_data['id'] = plan.id
            return jsonify({
                'success': True,
                'plan': plan_data,
            })
        
        return jsonify({
            'success': False,
            'error': 'No active plan found'
        }), 404
    except Exception as e:
        return jsonify({
            'success': False,
            'error': f'Error fetching plan: {str(e)}'
        }), 500


# ============================================================================
# GUIDER INTERVENTION IN CHARACTER CHATS
# ============================================================================

# Markers that suggest the user may need Guider support
EMOTIONAL_INTENSITY_MARKERS = [
    'i can\'t', 'i cant', 'too much', 'overwhelming', 'scared', 'terrified',
    'hate myself', 'hate my', 'worthless', 'hopeless', 'give up', 'giving up',
    'can\'t cope', 'cant cope', 'falling apart', 'breaking down', 'panic',
    'anxiety', 'depressed', 'suicidal', 'hurt myself', 'end it', 'no point',
    'exhausted', 'drained', 'stuck', 'trapped', 'alone', 'nobody cares',
    'what\'s wrong with me', 'whats wrong with me', 'i\'m broken', 'im broken',
]

STUCK_LOOP_PHRASES = [
    'i don\'t know', 'i dont know', 'not sure', 'confused', 'same thing',
    'going in circles', 'nothing works', 'tried everything', 'always the same',
    'keeps happening', 'can\'t figure', 'cant figure',
]

CRISIS_KEYWORDS = [
    'suicidal', 'suicide', 'kill myself', 'hurt myself', 'self-harm', 'self harm',
    'end my life', 'don\'t want to live', 'dont want to live', 'better off dead',
]


def analyze_intervention_need(messages: List[Dict[str, str]], character_id: str) -> Dict[str, Any]:
    """Analyze conversation to determine if Guider intervention would be helpful."""
    if len(messages) < 3:
        return {'shouldIntervene': False}
    
    # Get recent user messages (last 6)
    recent_user_messages = [
        m['content'].lower() for m in messages[-6:] 
        if m.get('role') == 'user'
    ]
    
    if not recent_user_messages:
        return {'shouldIntervene': False}
    
    combined_text = ' '.join(recent_user_messages)
    
    # Check for crisis keywords (highest priority)
    for keyword in CRISIS_KEYWORDS:
        if keyword in combined_text:
            return {
                'shouldIntervene': True,
                'reason': 'crisis_detected',
                'severity': 'high',
                'message': 'I sense you may be going through something very difficult. Would you like to talk to The Guider? They can help you find support.',
            }
    
    # Count emotional intensity markers
    intensity_count = sum(1 for marker in EMOTIONAL_INTENSITY_MARKERS if marker in combined_text)
    
    # Check for stuck loop patterns
    stuck_count = sum(1 for phrase in STUCK_LOOP_PHRASES if phrase in combined_text)
    
    # Check for repetitive themes (same phrases appearing multiple times)
    repetition_detected = False
    if len(recent_user_messages) >= 3:
        # Check if user is repeating similar messages
        for i in range(len(recent_user_messages) - 1):
            for j in range(i + 1, len(recent_user_messages)):
                # Simple similarity check
                words_i = set(recent_user_messages[i].split())
                words_j = set(recent_user_messages[j].split())
                if len(words_i) > 3 and len(words_j) > 3:
                    overlap = len(words_i & words_j)
                    if overlap / max(len(words_i), len(words_j)) > 0.6:
                        repetition_detected = True
                        break
    
    # Determine intervention level
    if intensity_count >= 3 or (intensity_count >= 2 and stuck_count >= 2):
        return {
            'shouldIntervene': True,
            'reason': 'emotional_intensity',
            'severity': 'medium',
            'message': f'It sounds like this conversation is bringing up a lot. The Guider is here if you want a calmer space to process what you\'re feeling.',
        }
    
    if stuck_count >= 3 or repetition_detected:
        return {
            'shouldIntervene': True,
            'reason': 'stuck_loop',
            'severity': 'low',
            'message': 'You seem to be working through something challenging. Would it help to step back and talk with The Guider for a broader perspective?',
        }
    
    # Check message count - suggest guider after extended sessions
    total_user_messages = sum(1 for m in messages if m.get('role') == 'user')
    if total_user_messages >= 15 and total_user_messages % 5 == 0:
        return {
            'shouldIntervene': True,
            'reason': 'session_length',
            'severity': 'low',
            'message': 'You\'ve been exploring deeply with this part. The Guider can help you reflect on what you\'ve learned so far.',
        }
    
    return {'shouldIntervene': False}


def generate_guider_intervention_message(
    uid: str,
    character_id: str,
    reason: str,
    messages: List[Dict[str, str]],
) -> str:
    """Generate a personalized intervention message from The Guider."""
    # Get character display name
    character_names = {
        'inner_critic': 'The Inner Critic',
        'perfectionist': 'The Perfectionist',
        'people_pleaser': 'The People Pleaser',
        'lonely_part': 'The Lonely Part',
        'workaholic': 'The Workaholic',
        'procrastinator': 'The Procrastinator',
        'fearful_part': 'The Fearful Part',
        'wounded_child': 'The Wounded Child',
    }
    character_name = character_names.get(character_id, 'this inner part')
    
    # Generate context-aware message using AI
    try:
        intervention_prompt = f"""You are The Guider, a compassionate companion helping users explore their inner world.

The user has been chatting with {character_name} and may need some gentle support.
Reason for intervention: {reason}

Generate a SHORT (1-2 sentences) caring message that:
- Acknowledges their feelings without being overwhelming
- Gently offers yourself as a space for reflection
- Does NOT pressure them to switch

Keep it warm and brief. End with an implicit invitation, not a question."""

        response = openai_client.chat.completions.create(
            model=OPENAI_MODEL,
            messages=[
                {'role': 'system', 'content': intervention_prompt},
                {'role': 'user', 'content': f'Recent context: {messages[-3:]}'},
            ],
            temperature=0.7,
            max_tokens=100,
        )
        return response.choices[0].message.content.strip()
    except Exception as e:
        print(f"[intervention] Error generating message: {e}")
        # Fallback messages based on reason
        fallbacks = {
            'crisis_detected': 'I\'m here if you need a calm space. You don\'t have to go through this alone.',
            'emotional_intensity': 'It sounds like a lot is coming up. I\'m here when you need a moment to breathe.',
            'stuck_loop': 'Sometimes stepping back helps us see more clearly. I\'m here if you want to reflect.',
            'session_length': 'You\'ve been exploring deeply. I\'m here if you want to process what you\'ve discovered.',
        }
        return fallbacks.get(reason, 'I\'m here if you want to talk.')


@app.route('/check_intervention', methods=['POST'])
def check_intervention():
    """Check if Guider intervention is recommended for a character chat."""
    try:
        data = request.json or {}
        uid = data.get('uid')
        character_id = data.get('characterId', '')
        messages = data.get('messages', [])
        
        if not uid:
            return jsonify({
                'success': False,
                'error': 'uid is required'
            }), 400
        
        # Analyze if intervention is needed
        analysis = analyze_intervention_need(messages, character_id)
        
        if not analysis.get('shouldIntervene'):
            return jsonify({
                'success': True,
                'shouldIntervene': False,
            })
        
        # Generate personalized intervention message
        intervention_message = generate_guider_intervention_message(
            uid=uid,
            character_id=character_id,
            reason=analysis.get('reason', 'general'),
            messages=messages,
        )
        
        return jsonify({
            'success': True,
            'shouldIntervene': True,
            'reason': analysis.get('reason'),
            'severity': analysis.get('severity'),
            'guiderMessage': intervention_message,
        })
    except Exception as e:
        traceback.print_exc()
        return jsonify({
            'success': False,
            'error': f'Intervention check error: {str(e)}'
        }), 500


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=True)
