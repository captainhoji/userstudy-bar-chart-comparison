const PHONE_MESSAGES = [
  { sender: 'Alex', text: 'Are you free later?' },
  { sender: 'Maya', text: 'Did you see the update?' },
  { sender: 'Sam', text: 'Lunch at 12?' },
  { sender: 'Jordan', text: 'Check this out.' },
  { sender: 'Chris', text: 'Can you call me?' },
  { sender: 'Alex', text: 'Please like this.' },
  { sender: 'Taylor', text: 'Meeting moved to 3.' },
  { sender: 'Maya', text: 'Photo from the trip' },
  { sender: 'Sam', text: 'Thanks!' },
  { sender: 'Jordan', text: 'Reminder for tomorrow.' }
];

export const PHONE_LIKE_SENDERS = ['Alex', 'Maya'];

export const PHONE_TIMING = {
  MESSAGE_VISIBLE_MS: 3000,
  GAP_MIN_MS: 500,
  GAP_MAX_MS: 2000
};

function createMessageElement(message, isActive, liked) {
  const messageEl = document.createElement('div');
  messageEl.className = `phone-message${isActive ? ' active' : ''}`;
  const heartHTML = liked ? '<span class="phone-heart">❤</span>' : '';
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
  let active = false;
  let stats = { total: 0, correct: 0 };

  function resolveCurrentMessage() {
    if (!currentMessage) return;
    const shouldLike = PHONE_LIKE_SENDERS.includes(currentMessage.sender);
    const isCorrect = shouldLike ? currentLiked : !currentLiked;
    stats.total += 1;
    if (isCorrect) stats.correct += 1;
    currentMessage = null;
    currentLiked = false;
  }

  function renderMessages(newMessage) {
    if (!container) return;
    container.innerHTML = '';
    const messagesToShow = [];
    if (newMessage) messagesToShow.push(newMessage);
    messagesToShow.forEach((msg, idx) => {
      const messageEl = createMessageElement(msg, idx === 0, currentLiked);
      container.appendChild(messageEl);
    });
  }

  function scheduleNextMessage() {
    if (!active) return;
    const delay = PHONE_TIMING.GAP_MIN_MS + Math.random() * (PHONE_TIMING.GAP_MAX_MS - PHONE_TIMING.GAP_MIN_MS);
    showTimerId = window.setTimeout(() => {
      currentMessage = PHONE_MESSAGES[messageIndex % PHONE_MESSAGES.length];
      messageIndex += 1;
      currentLiked = false;
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
      scheduleNextMessage();
      document.addEventListener('keydown', handleLikeKey);
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
      if (container) container.innerHTML = '';
    },
    getStats() {
      const accuracy = stats.total === 0 ? null : stats.correct / stats.total;
      return { ...stats, accuracy };
    }
  };
}
