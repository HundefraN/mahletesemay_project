/**
 * Firebase Firestore Exporter
 * Extracts documents and subcollections using the Firebase Admin SDK.
 */

import fs from 'fs';
import admin from 'firebase-admin';

export class FirebaseExporter {
  constructor(serviceAccountPath) {
    this.serviceAccountPath = serviceAccountPath;
    this.db = null;
    this.initialized = false;
  }

  async init() {
    if (this.initialized) return;

    if (!fs.existsSync(this.serviceAccountPath)) {
      throw new Error(
        `Firebase Service Account Key not found at: ${this.serviceAccountPath}.\n` +
        `Please download your service account JSON key from Firebase Console -> Project Settings -> Service Accounts, and place it at ${this.serviceAccountPath} or set FIREBASE_SERVICE_ACCOUNT_KEY in .env`
      );
    }

    const serviceAccount = JSON.parse(fs.readFileSync(this.serviceAccountPath, 'utf8'));

    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
    }

    this.db = admin.firestore();
    this.initialized = true;
  }

  async exportCollection(collectionName) {
    await this.init();
    const snapshot = await this.db.collection(collectionName).get();
    const records = [];
    snapshot.forEach(doc => {
      records.push({
        id: doc.id,
        data: doc.data(),
      });
    });
    return records;
  }

  async exportVocalPlansWithDays() {
    await this.init();
    const plansSnapshot = await this.db.collection('vocal_plans').get();
    const results = [];

    // Predefined default vocal plans if empty
    const defaultPlanIds = [
      'male_daily', 'female_daily', 'male_weekly', 'female_weekly',
      'male_monthly', 'female_monthly', 'male_quarterly', 'female_quarterly'
    ];

    const planIds = new Set(defaultPlanIds);
    plansSnapshot.forEach(doc => planIds.add(doc.id));

    for (const planId of planIds) {
      const daysSnapshot = await this.db.collection('vocal_plans').doc(planId).collection('days').get();
      const days = [];
      daysSnapshot.forEach(doc => {
        days.push({
          id: doc.id,
          planId: planId,
          data: doc.data(),
        });
      });

      results.push({
        planId,
        days,
      });
    }

    return results;
  }

  async exportAll() {
    await this.init();
    console.log('📡 Fetching records from Firestore...');

    const [
      artists,
      albums,
      songs,
      generalExercises,
      vocalPlans,
      moderators,
      suggestions,
      invitations,
      activityLogs,
      inviteCodes,
    ] = await Promise.all([
      this.exportCollection('artists').catch(() => []),
      this.exportCollection('albums').catch(() => []),
      this.exportCollection('songs').catch(() => []),
      this.exportCollection('general_exercises').catch(() => []),
      this.exportVocalPlansWithDays().catch(() => []),
      this.exportCollection('moderators').catch(() => []),
      this.exportCollection('suggestions').catch(() => []),
      this.exportCollection('invitations').catch(() => []),
      this.exportCollection('activity_logs').catch(() => []),
      this.exportCollection('invite_codes').catch(() => []),
    ]);

    return {
      artists,
      albums,
      songs,
      generalExercises,
      vocalPlans,
      moderators,
      suggestions,
      invitations,
      activityLogs,
      inviteCodes,
    };
  }
}
