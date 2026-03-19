export const PHONE_LIKE_RULE = 'pet-keywords';

export const PHONE_TIMING = {
  MESSAGE_VISIBLE_MS: 3000,
  GAP_MIN_MS: 500,
  GAP_MAX_MS: 1000
};

const PHONE_MESSAGES_CSV = '/static/phone_messages.csv';
const PET_MESSAGES_CSV = '/static/pet_messages.csv';

function createMessageElement(message, isActive, likedStatus) {
  const messageEl = document.createElement('div');
  const statusClass = likedStatus ? ` ${likedStatus}` : '';
  const angryClass = message && message.text === '😡' ? ' angry-feedback' : '';
  messageEl.className = `phone-message${isActive ? ' active' : ''}${statusClass}${angryClass}`;
  const heartHTML = likedStatus ? '<span class="phone-heart">❤</span>' : '';
  messageEl.innerHTML = `
    <div class="phone-sender">${message.sender}${heartHTML}</div>
    <div class="phone-text">${message.text}</div>
  `;
  return messageEl;
}

export function createPhoneTask() {
  let container = null;
  let showTimerId = null;
  let hideTimerId = null;
  let angryTimerId = null;
  let messageIndex = 0;
  let phoneChunkIndex = 0;
  let phoneMessageIndex = 0;
  let lastPhoneId = null;
  let phoneCycleCompleted = false;
  let currentMessage = null;
  let currentLiked = false;
  let currentLikedStatus = null;
  let currentShouldLike = false;
  let acceptingInput = false;
  let active = false;
  let stats = { total: 0, correct: 0, hit: 0, miss: 0, falseAlarm: 0, correctRejection: 0 };
  let baseChunks = [];
  let phoneChunks = [];
  let petMessages = [];
  let petIndex = 0;
  let lastPetId = null;
  let petCycleCompleted = false;
  let loadPromise = null;
  let forcePetOnNextMessage = false;
  // Allow per-study overrides (e.g., shorter phone display in bar-chart mode).
  let messageVisibleMs = PHONE_TIMING.MESSAGE_VISIBLE_MS;

  function parsePhoneCsv(text) {
    const lines = text.trim().split('\n');
    const rows = [];
    for (let i = 1; i < lines.length; i += 1) {
      const line = lines[i].trim();
      if (!line) continue;
      const parts = line.split(',');
      if (parts.length < 3) continue;
      const chunkId = parts[0].trim();
      const sender = parts[1].trim();
      const messageText = parts.slice(2).join(',').trim();
      rows.push({ chunkId, sender, text: messageText, isPet: false });
    }
    return rows;
  }

  function parsePetCsv(text) {
    const lines = text.trim().split('\n');
    if (!lines.length) return [];
    const header = lines[0].split(',').map((h) => h.trim().toLowerCase());
    const senderIdx = header.indexOf('sender');
    const textIdx = header.indexOf('text');
    const rows = [];
    for (let i = 1; i < lines.length; i += 1) {
      const line = lines[i].trim();
      if (!line) continue;
      const parts = line.split(',');
      if (parts.length < 2) continue;
      const sender = senderIdx >= 0 ? parts[senderIdx].trim() : parts[0].trim();
      const messageText = textIdx >= 0 ? parts[textIdx].trim() : parts.slice(1).join(',').trim();
      rows.push({ sender, text: messageText, isPet: true });
    }
    return rows;
  }

  function shuffleArray(arr) {
    const copy = arr.slice();
    for (let i = copy.length - 1; i > 0; i -= 1) {
      const j = Math.floor(Math.random() * (i + 1));
      [copy[i], copy[j]] = [copy[j], copy[i]];
    }
    return copy;
  }

  function buildPhoneChunks() {
    phoneChunks = shuffleArray(baseChunks);
    phoneChunkIndex = 0;
    phoneMessageIndex = 0;
    phoneCycleCompleted = false;
  }

  function buildPetMessages() {
    petMessages = shuffleArray(petMessages);
    petIndex = 0;
    petCycleCompleted = false;
  }

  function loadMessages() {
    if (loadPromise) return loadPromise;
    loadPromise = Promise.all([
      fetch(PHONE_MESSAGES_CSV).then((res) => res.text()),
      fetch(PET_MESSAGES_CSV).then((res) => res.text())
    ])
      .then(([phoneText, petText]) => {
        const rows = parsePhoneCsv(phoneText);
        const chunksMap = new Map();
        rows.forEach((row) => {
          if (!chunksMap.has(row.chunkId)) chunksMap.set(row.chunkId, []);
          chunksMap.get(row.chunkId).push({ sender: row.sender, text: row.text, isPet: false });
        });
        baseChunks = Array.from(chunksMap.values());
        buildPhoneChunks();

        petMessages = parsePetCsv(petText);
        petMessages = shuffleArray(petMessages);
        petIndex = 0;
        petCycleCompleted = false;
      })
      .catch(() => {
        console.error('Failed to load phone CSV files.');
        baseChunks = [];
        phoneChunks = [];
        petMessages = [];
      });
    return loadPromise;
  }

  function getNextPhoneMessage() {
    if (!phoneChunks.length) return null;

    if (phoneChunkIndex >= phoneChunks.length) {
      buildPhoneChunks();
    }

    const currentChunk = phoneChunks[phoneChunkIndex];
    if (!currentChunk || !currentChunk.length) return null;

    let msg = currentChunk[phoneMessageIndex];
    phoneMessageIndex += 1;

    if (phoneMessageIndex >= currentChunk.length) {
      phoneMessageIndex = 0;
      phoneChunkIndex += 1;
      if (phoneChunkIndex >= phoneChunks.length) {
        phoneCycleCompleted = true;
      }
    }

    if (!msg) return null;

    const msgId = `${msg.sender}:${msg.text}`;
    if (msgId === lastPhoneId && !phoneCycleCompleted) {
      // advance once to avoid immediate repeat
      const next = getNextPhoneMessage();
      if (next) return next;
    }
    lastPhoneId = msgId;
    return msg;
  }

  function getNextPetMessage() {
    if (!petMessages.length) return null;

    if (petIndex >= petMessages.length) {
      petMessages = shuffleArray(petMessages);
      petIndex = 0;
      petCycleCompleted = true;
    }

    let msg = petMessages[petIndex];
    petIndex += 1;
    if (!msg) return null;

    const msgId = `${msg.sender}:${msg.text}`;
    if (msgId === lastPetId && !petCycleCompleted) {
      const next = getNextPetMessage();
      if (next) return next;
    }
    lastPetId = msgId;
    return msg;
  }

  function resolveCurrentMessage() {
    if (!currentMessage) return false;
    const isCorrect = currentShouldLike ? currentLiked : !currentLiked;
    stats.total += 1;
    if (isCorrect) stats.correct += 1;
    if (currentShouldLike && currentLiked) {
      stats.hit += 1;
    } else if (currentShouldLike && !currentLiked) {
      stats.miss += 1;
    } else if (!currentShouldLike && currentLiked) {
      stats.falseAlarm += 1;
    } else {
      stats.correctRejection += 1;
    }
    return isCorrect;
  }

  function clearCurrentMessageState() {
    currentMessage = null;
    currentLiked = false;
    currentLikedStatus = null;
    currentShouldLike = false;
    acceptingInput = false;
  }

  function renderMessages(messages) {
    if (!container) return;
    container.innerHTML = '';
    const messagesToShow = Array.isArray(messages) ? messages : (messages ? [messages] : []);
    const ordered = messagesToShow.length > 1 ? messagesToShow.slice().reverse() : messagesToShow;
    ordered.forEach((msg, idx) => {
      const messageEl = createMessageElement(msg, idx === 0, idx === 0 ? currentLikedStatus : null);
      container.appendChild(messageEl);
    });
  }

  function scheduleNextMessage() {
    if (!active) return;
    if (showTimerId) window.clearTimeout(showTimerId);
    if (hideTimerId) window.clearTimeout(hideTimerId);
    if (angryTimerId) window.clearTimeout(angryTimerId);
    const delay = PHONE_TIMING.GAP_MIN_MS + Math.random() * (PHONE_TIMING.GAP_MAX_MS - PHONE_TIMING.GAP_MIN_MS);
    showTimerId = window.setTimeout(() => {
      const usePet = forcePetOnNextMessage ? true : Math.random() < 0.4;
      forcePetOnNextMessage = false;
      const nextMessage = usePet ? getNextPetMessage() : getNextPhoneMessage();
      currentMessage = nextMessage || getNextPhoneMessage() || getNextPetMessage();
      if (!currentMessage) {
        console.warn('Phone task has no message to show.');
        scheduleNextMessage();
        return;
      }
      currentLiked = false;
      currentLikedStatus = null;
      currentShouldLike = currentMessage.isPet;
      acceptingInput = true;
      renderMessages(currentMessage);
      hideTimerId = window.setTimeout(() => {
        const isCorrect = resolveCurrentMessage();
        acceptingInput = false;
        if (currentShouldLike && !currentLiked) {
          const angryMessage = { sender: currentMessage.sender, text: "😡", isPet: false };
          renderMessages([currentMessage, angryMessage]);
          angryTimerId = window.setTimeout(() => {
            renderMessages(null);
            clearCurrentMessageState();
            scheduleNextMessage();
            angryTimerId = null;
          }, 2000);
        } else {
          renderMessages(null);
          clearCurrentMessageState();
          scheduleNextMessage();
        }
      }, messageVisibleMs);
    }, delay);
  }

  function handleLikeKey(event) {
    if (!active) return;
    if (!acceptingInput) return;
    if (event.code !== 'Space') return;
    event.preventDefault();
    if (!currentMessage) return;
    currentLiked = true;
    currentLikedStatus = currentShouldLike ? 'liked-correct' : 'liked-incorrect';
    renderMessages(currentMessage);
  }

  return {
    attach(screenElement) {
      if (container === screenElement) return;
      container = screenElement;
      if (container && currentMessage) renderMessages(currentMessage);
    },
    start() {
      if (active) return;
      active = true;
      loadMessages().then(() => {
        if (!active) return;
        scheduleNextMessage();
        document.addEventListener('keydown', handleLikeKey);
      });
    },
    pause() {
      active = false;
      if (showTimerId) window.clearTimeout(showTimerId);
      if (hideTimerId) window.clearTimeout(hideTimerId);
      if (angryTimerId) window.clearTimeout(angryTimerId);
      showTimerId = null;
      hideTimerId = null;
      angryTimerId = null;
      clearCurrentMessageState();
      document.removeEventListener('keydown', handleLikeKey);
    },
    resetStats() {
      stats = { total: 0, correct: 0, hit: 0, miss: 0, falseAlarm: 0, correctRejection: 0 };
      messageIndex = 0;
      phoneChunkIndex = 0;
      phoneMessageIndex = 0;
      lastPhoneId = null;
      phoneCycleCompleted = false;
      clearCurrentMessageState();
      if (container) container.innerHTML = '';
      if (baseChunks.length) {
        buildPhoneChunks();
      }
      if (petMessages.length) {
        petMessages = shuffleArray(petMessages);
        petIndex = 0;
        lastPetId = null;
        petCycleCompleted = false;
      }
    },
    getStats() {
      const accuracy = stats.total === 0 ? null : stats.correct / stats.total;
      return { ...stats, accuracy };
    },
    setForcePetOnNextMessage(shouldForce) {
      forcePetOnNextMessage = !!shouldForce;
    },
    setMessageVisibleMs(ms) {
      const numeric = Number(ms);
      // Guard against invalid/too-small values that make the task unusable.
      messageVisibleMs = Number.isFinite(numeric) && numeric >= 250
        ? Math.round(numeric)
        : PHONE_TIMING.MESSAGE_VISIBLE_MS;
    }
  };
}
