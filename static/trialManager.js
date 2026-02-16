const responseQueue = [];
let isDrainingQueue = false;

const RESPONSE_BATCH_SIZE = 20;
const RESPONSE_MAX_RETRIES = 5;
const RESPONSE_RETRY_BASE_MS = 300;

function sleep(ms) {
  return new Promise((resolve) => window.setTimeout(resolve, ms));
}

async function postResponseBatch(batchItems) {
  try {
    const fetchResponse = await fetch('/save_responses_batch', {
      method: 'POST',
      keepalive: true,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        responses: batchItems.map((item) => item.payload)
      })
    });
    return fetchResponse.ok;
  } catch (error) {
    console.error('Failed to post response batch:', error);
    return false;
  }
}

async function drainResponseQueue() {
  if (isDrainingQueue) return;
  isDrainingQueue = true;

  while (responseQueue.length > 0) {
    const now = Date.now();
    const first = responseQueue[0];
    if (first.nextTryAt > now) {
      await sleep(first.nextTryAt - now);
      continue;
    }

    const batchItems = responseQueue.slice(0, RESPONSE_BATCH_SIZE);
    const ok = await postResponseBatch(batchItems);

    if (ok) {
      responseQueue.splice(0, batchItems.length);
      continue;
    }

    const retryDelay = RESPONSE_RETRY_BASE_MS * (2 ** Math.max(0, batchItems[0].attempts));
    const nextTryAt = Date.now() + retryDelay;

    for (let i = 0; i < batchItems.length; i += 1) {
      const item = responseQueue[i];
      item.attempts += 1;
      if (item.attempts > RESPONSE_MAX_RETRIES) {
        console.error('Dropping response after max retries:', item.payload);
      } else {
        item.nextTryAt = nextTryAt;
      }
    }

    while (responseQueue.length > 0 && responseQueue[0].attempts > RESPONSE_MAX_RETRIES) {
      responseQueue.shift();
    }
  }

  isDrainingQueue = false;
}

export function saveResponseToServer({
  participantId,
  response,
  correct,
  trialNumber,
  timeWhen,
  stimuliNumber,
  duration,
  responseTime,
  heatmapCondition,
  legendCondition,
  labelCondition,
  attention
}) {
  responseQueue.push({
    payload: {
      participant_id: participantId,
      response,
      correct,
      trial_number: trialNumber,
      time_when: timeWhen,
      stimuli_number: stimuliNumber,
      duration,
      response_time: responseTime,
      heatmap_condition: heatmapCondition,
      legend_condition: legendCondition,
      label_condition: labelCondition,
      attention
    },
    attempts: 0,
    nextTryAt: 0
  });

  void drainResponseQueue();
  return true;
}

export async function flushResponseQueue({ timeoutMs = 12000 } = {}) {
  const start = Date.now();
  void drainResponseQueue();

  while (Date.now() - start < timeoutMs) {
    if (responseQueue.length === 0 && !isDrainingQueue) {
      return true;
    }
    await sleep(80);
  }

  console.warn('flushResponseQueue timed out with pending items:', responseQueue.length);
  return responseQueue.length === 0;
}

export async function savePracticeSummary({
  participantId,
  practiceAccuracy,
  practiceAccuracyPhone,
  practicePhoneHit,
  practicePhoneMiss,
  practicePhoneFalseAlarm,
  practicePhoneCorrectRejection
}) {
  try {
    await fetch('/save_practice_summary', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        participant_id: participantId,
        practice_accuracy: practiceAccuracy,
        practice_accuracy_phone: practiceAccuracyPhone,
        hit: practicePhoneHit,
        miss: practicePhoneMiss,
        false_alarm: practicePhoneFalseAlarm,
        correct_rejection: practicePhoneCorrectRejection
      })
    });
  } catch (error) {
    console.error('Failed to save practice summary:', error);
  }
}

export async function savePhoneSummary({
  participantId,
  phoneHit,
  phoneMiss,
  phoneFalseAlarm,
  phoneCorrectRejection
}) {
  try {
    const response = await fetch('/save_phone_summary', {
      method: 'POST',
      keepalive: true,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        participant_id: participantId,
        hit: phoneHit,
        miss: phoneMiss,
        false_alarm: phoneFalseAlarm,
        correct_rejection: phoneCorrectRejection
      })
    });
    return response.ok;
  } catch (error) {
    console.error('Failed to save phone summary:', error);
    return false;
  }
}
