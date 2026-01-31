/* eslint-disable no-console */
const admin = require('firebase-admin');

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();
const { FieldValue } = admin.firestore;
const BATCH_SIZE = 400;

function shouldSetNestedDefaults(container) {
  return container === undefined || container === null || typeof container === 'object';
}

function buildUpdates(data) {
  const updates = {};

  if (!Object.prototype.hasOwnProperty.call(data, 'createdAt')) {
    updates.createdAt = FieldValue.serverTimestamp();
  }

  if (
    !Object.prototype.hasOwnProperty.call(data, 'updatedAt') ||
    data.updatedAt instanceof admin.firestore.Timestamp
  ) {
    updates.updatedAt = FieldValue.serverTimestamp();
  }

  if (!Object.prototype.hasOwnProperty.call(data, 'lastActiveAt')) {
    updates.lastActiveAt = FieldValue.serverTimestamp();
  }

  if (!Object.prototype.hasOwnProperty.call(data, 'lastAgentRunAt')) {
    updates.lastAgentRunAt = null;
  }

  const settings = data.settings;
  if (shouldSetNestedDefaults(settings)) {
    if (!settings || !Object.prototype.hasOwnProperty.call(settings, 'theme')) {
      updates['settings.theme'] = 'system';
    }
    if (
      !settings ||
      !Object.prototype.hasOwnProperty.call(settings, 'notificationsEnabled')
    ) {
      updates['settings.notificationsEnabled'] = true;
    }
    if (!settings || !Object.prototype.hasOwnProperty.call(settings, 'voiceEnabled')) {
      updates['settings.voiceEnabled'] = true;
    }
  }

  const progressSummary = data.progressSummary;
  if (shouldSetNestedDefaults(progressSummary)) {
    if (
      !progressSummary ||
      !Object.prototype.hasOwnProperty.call(progressSummary, 'currentStage')
    ) {
      updates['progressSummary.currentStage'] = 'exploring';
    }
    if (
      !progressSummary ||
      !Object.prototype.hasOwnProperty.call(progressSummary, 'streakDays')
    ) {
      updates['progressSummary.streakDays'] = 0;
    }
    if (
      !progressSummary ||
      !Object.prototype.hasOwnProperty.call(progressSummary, 'lastSessionAt')
    ) {
      updates['progressSummary.lastSessionAt'] = null;
    }
  }

  return updates;
}

async function migrateUsersDefaults() {
  let lastDoc = null;
  let processed = 0;
  let updated = 0;
  let skipped = 0;
  let batchIndex = 0;

  while (true) {
    let query = db
      .collection('users')
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(BATCH_SIZE);

    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snapshot = await query.get();
    if (snapshot.empty) break;

    const batch = db.batch();
    let batchUpdates = 0;

    snapshot.docs.forEach((doc) => {
      const data = doc.data() || {};
      const updates = buildUpdates(data);
      processed += 1;

      if (Object.keys(updates).length > 0) {
        batch.set(doc.ref, updates, { merge: true });
        batchUpdates += 1;
      }
    });

    if (batchUpdates > 0) {
      await batch.commit();
      updated += batchUpdates;
    } else {
      skipped += snapshot.size;
    }

    batchIndex += 1;
    lastDoc = snapshot.docs[snapshot.docs.length - 1];

    console.log(
      `Batch ${batchIndex}: processed ${snapshot.size}, updated ${batchUpdates}`,
    );
  }

  console.log('Migration complete.');
  console.log(`Processed: ${processed}`);
  console.log(`Updated: ${updated}`);
  console.log(`Skipped (no changes needed): ${skipped}`);
}

migrateUsersDefaults().catch((error) => {
  console.error('Migration failed:', error);
  process.exit(1);
});
