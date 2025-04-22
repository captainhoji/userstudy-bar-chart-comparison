import { stopTimer } from './utils.js';

export async function saveResponseToServer({
  participantId,
  task,
  response,
  correct,
  trialNumber,
  timeWhen,
  layout,
  orientation,
  label,
  stimuliNumber,
  duration
}) {
  try {
    await fetch('/save_response', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        participant_id: participantId,
        task,
        response,
        correct,
        trial_number: trialNumber,
        time_when: timeWhen,
        layout,
        orientation,
        label,
        stimuli_number: stimuliNumber,
        duration
      })
    });
  } catch (error) {
    console.error('Failed to save response:', error);
  }
}

export async function getPracticeData() {
  try {
    const res = await fetch('/get_practice', {
      method: 'GET',
      headers: { 'Content-Type': 'application/json' }
    });
    const data = await res.json();
    return data.practice;
  } catch (err) {
    console.error('Error fetching practice data:', err);
    return [];
  }
}