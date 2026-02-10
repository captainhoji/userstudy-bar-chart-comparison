export const PHONE_LIKE_RULE = 'pet-keywords';

export const PHONE_TIMING = {
  MESSAGE_VISIBLE_MS: 3000,
  GAP_MIN_MS: 500,
  GAP_MAX_MS: 1000
};

const PHONE_MESSAGES_CSV = '/static/phone_messages.csv';

const PET_KEYWORDS = [
  // dog-related
  'leash','walk','bark','wag','treat','fetch','puppy',
  // cat-related
  'meow','purr','litter','whisker','scratch','claw','kitten','catnip',
  // parrot-related
  'squawk','feather','cage','perch','wing','bird seed','seed',
  // goldfish-related
  'bowl','tank','filter','gill','fin','flakes','aquarium','water change','pebble'
];

function hasPetKeyword(text) {
  const lower = text.toLowerCase();
  return PET_KEYWORDS.some((word) => lower.includes(word));
}

function createMessageElement(message, isActive, likedStatus) {
  const messageEl = document.createElement('div');
  const statusClass = likedStatus ? ` ${likedStatus}` : '';
  messageEl.className = `phone-message${isActive ? ' active' : ''}${statusClass}`;
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
  let messageIndex = 0;
  let currentMessage = null;
  let currentLiked = false;
  let currentLikedStatus = null;
  let currentShouldLike = false;
  let active = false;
  let stats = { total: 0, correct: 0 };
  let baseChunks = [];
  let messageSequence = [];
  let loadPromise = null;

  function parseCsv(text) {
    const lines = text.trim().split('\n');
    const rows = [];
    for (let i = 1; i < lines.length; i += 1) {
      const line = lines[i].trim();
      if (!line) continue;
      const parts = line.split(',');
      if (parts.length < 4) continue;
      const chunkId = parts[0].trim();
      const sender = parts[1].trim();
      const petMention = parts[parts.length - 1].trim().toLowerCase();
      const messageText = parts.slice(2, parts.length - 1).join(',').trim();
      rows.push({ chunkId, sender, text: messageText, petMention });
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

  function buildSequence() {
    const shuffledChunks = shuffleArray(baseChunks);
    messageSequence = shuffledChunks.flatMap((chunk) => chunk);
    messageIndex = 0;
  }

  function loadMessages() {
    if (loadPromise) return loadPromise;
    loadPromise = fetch(PHONE_MESSAGES_CSV)
      .then((res) => res.text())
      .then((text) => {
        const rows = parseCsv(text);
        const chunksMap = new Map();
        rows.forEach((row) => {
          if (!chunksMap.has(row.chunkId)) chunksMap.set(row.chunkId, []);
          chunksMap.get(row.chunkId).push({ sender: row.sender, text: row.text, petMention: row.petMention });
        });
        baseChunks = Array.from(chunksMap.values());
        buildSequence();
      })
      .catch(() => {
        baseChunks = [];
        messageSequence = [];
      });
    return loadPromise;
  }

  function resolveCurrentMessage() {
    if (!currentMessage) return;
    const isCorrect = currentShouldLike ? currentLiked : !currentLiked;
    stats.total += 1;
    if (isCorrect) stats.correct += 1;
    currentMessage = null;
    currentLiked = false;
    currentLikedStatus = null;
    currentShouldLike = false;
  }

  function renderMessages(newMessage) {
    if (!container) return;
    container.innerHTML = '';
    const messagesToShow = [];
    if (newMessage) messagesToShow.push(newMessage);
    messagesToShow.forEach((msg, idx) => {
      const messageEl = createMessageElement(msg, idx === 0, currentLikedStatus);
      container.appendChild(messageEl);
    });
  }

  function scheduleNextMessage() {
    if (!active) return;
    const delay = PHONE_TIMING.GAP_MIN_MS + Math.random() * (PHONE_TIMING.GAP_MAX_MS - PHONE_TIMING.GAP_MIN_MS);
    showTimerId = window.setTimeout(() => {
      if (!messageSequence.length) return;
      currentMessage = messageSequence[messageIndex % messageSequence.length];
      messageIndex += 1;
      currentLiked = false;
      currentLikedStatus = null;
      currentShouldLike = currentMessage.petMention === 'yes' || hasPetKeyword(currentMessage.text);
      renderMessages(currentMessage);
      hideTimerId = window.setTimeout(() => {
        resolveCurrentMessage();
        renderMessages(null);
        scheduleNextMessage();
      }, PHONE_TIMING.MESSAGE_VISIBLE_MS);
    }, delay);
  }

  function handleLikeKey(event) {
    if (!active) return;
    if (event.code !== 'Space') return;
    event.preventDefault();
    if (!currentMessage) return;
    currentLiked = true;
    currentLikedStatus = currentShouldLike ? 'liked-correct' : 'liked-incorrect';
    renderMessages(currentMessage);
  }

  return {
    attach(screenElement) {
      container = screenElement;
      if (container) {
        container.innerHTML = '';
        if (currentMessage) renderMessages(currentMessage);
      }
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
      showTimerId = null;
      hideTimerId = null;
      resolveCurrentMessage();
      document.removeEventListener('keydown', handleLikeKey);
    },
    resetStats() {
      stats = { total: 0, correct: 0 };
      messageIndex = 0;
      currentMessage = null;
      currentLiked = false;
      currentLikedStatus = null;
      currentShouldLike = false;
      if (container) container.innerHTML = '';
      if (baseChunks.length) {
        buildSequence();
      }
    },
    getStats() {
      const accuracy = stats.total === 0 ? null : stats.correct / stats.total;
      return { ...stats, accuracy };
    }
  };
}
