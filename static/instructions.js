export function showInstructionsOverlay() {
  const overlay = document.getElementById("instruction-overlay");
  if (overlay) overlay.style.display = "flex";
}

export function hideInstructionsOverlay() {
  const overlay = document.getElementById("instruction-overlay");
  if (overlay) overlay.style.display = "none";
}
