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
  trialType,
  trialNumber,
  timeWhen,
  stimuliNumber,
  responseTime,
  heatmapCondition,
  legendCondition,
  labelCondition,
  attention,
  task,
  color,
  statementType,
  statementTruth,
  comparisonFrame
}) {
  responseQueue.push({
    payload: {
      participant_id: participantId,
      response,
      correct,
      trial_type: trialType || 'heatmap',
      trial_number: trialNumber,
      time_when: timeWhen,
      stimuli_number: stimuliNumber,
      response_time: responseTime,
      heatmap_condition: heatmapCondition,
      legend_condition: legendCondition,
      label_condition: labelCondition,
      attention,
      // Bar-chart mode fields (backend maps these into Trial_barchart.task/color).
      task: task || null,
      color: color || null,
      statement_type: statementType || null,
      statement_truth: statementTruth ?? null,
      comparison_frame: comparisonFrame || null
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
  const payload = {
    participant_id: participantId,
    hit: Number(phoneHit || 0),
    miss: Number(phoneMiss || 0),
    false_alarm: Number(phoneFalseAlarm || 0),
    correct_rejection: Number(phoneCorrectRejection || 0)
  };
  try {
    const response = await fetch('/save_phone_summary', {
      method: 'POST',
      keepalive: true,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    if (!response.ok) {
      console.error('Failed to save phone summary response:', response.status, payload);
    }
    return response.ok;
  } catch (error) {
    console.error('Failed to save phone summary:', error, payload);
    return false;
  }
}
