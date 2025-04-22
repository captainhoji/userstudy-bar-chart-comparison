let spaceHandler = null;
let arrowKeyHandler = null;

export function addKeyHandlers(onSpacePress, onArrowPress = null) {
  removeKeyHandlers();

  spaceHandler = function (event) {
    if (event.code === 'Space') {
      event.preventDefault();
      if (typeof onSpacePress === 'function') {
        removeKeyHandlers();
        onSpacePress();
      }
    }
  };

  arrowKeyHandler = function (event) {
    if (!onArrowPress) return;
    const arrowKeys = ['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown'];
    if (arrowKeys.includes(event.key) || arrowKeys.includes(event.code)) {
      event.preventDefault();
      onArrowPress(event);
    }
  };

  document.addEventListener('keydown', spaceHandler);
  if (onArrowPress) {
    document.addEventListener('keydown', arrowKeyHandler);
  }
}

export function removeKeyHandlers() {
  if (spaceHandler) document.removeEventListener('keydown', spaceHandler);
  if (arrowKeyHandler) document.removeEventListener('keydown', arrowKeyHandler);
  spaceHandler = null;
  arrowKeyHandler = null;
}