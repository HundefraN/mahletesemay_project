/**
 * Offline JSON File Exporter
 * Reads documents and records from local JSON files.
 */

import fs from 'fs';
import path from 'path';

export class JsonExporter {
  constructor(dataDir) {
    this.dataDir = dataDir;
  }

  readJsonFile(fileName) {
    const filePath = path.join(this.dataDir, fileName);
    if (!fs.existsSync(filePath)) {
      return [];
    }

    try {
      const content = fs.readFileSync(filePath, 'utf8');
      const parsed = JSON.parse(content);

      if (Array.isArray(parsed)) {
        return parsed.map((item, idx) => ({
          id: item.id || `json_item_${idx}`,
          data: item,
        }));
      }

      if (typeof parsed === 'object' && parsed !== null) {
        return Object.entries(parsed).map(([key, value]) => ({
          id: key,
          data: value,
        }));
      }

      return [];
    } catch (err) {
      console.warn(`⚠️ Error reading JSON file ${filePath}: ${err.message}`);
      return [];
    }
  }

  async exportAll() {
    console.log(`📁 Loading local JSON records from ${this.dataDir}...`);

    const artists = this.readJsonFile('artists.json');
    const albums = this.readJsonFile('albums.json');
    const songs = this.readJsonFile('songs.json');
    const generalExercises = this.readJsonFile('general_exercises.json');
    const vocalPlanDays = this.readJsonFile('vocal_plan_days.json');

    // Group vocal plan days
    const vocalPlans = [];
    const daysByPlan = {};

    vocalPlanDays.forEach(item => {
      const planId = item.data.planId || item.data.plan_id || 'male_daily';
      if (!daysByPlan[planId]) {
        daysByPlan[planId] = [];
      }
      daysByPlan[planId].push({
        id: item.id,
        planId,
        data: item.data,
      });
    });

    Object.entries(daysByPlan).forEach(([planId, days]) => {
      vocalPlans.push({ planId, days });
    });

    const moderators = this.readJsonFile('moderators.json');
    const suggestions = this.readJsonFile('suggestions.json');
    const invitations = this.readJsonFile('invitations.json');
    const activityLogs = this.readJsonFile('activity_logs.json');
    const inviteCodes = this.readJsonFile('invite_codes.json');

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
