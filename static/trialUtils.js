function barLength([floor, ceiling, color]) {
  return ceiling - floor;
}

function tallestBar(arr) {
  // returns { bar, length, index }
  let bestIndex = -1;
  let bestLen = -Infinity;

  for (let i = 0; i < arr.length; i++) {
    const len = barLength(arr[i]);
    if (len > bestLen) {
      bestLen = len;
      bestIndex = i;
    }
  }

  return bestIndex === -1
    ? null
    : { bar: arr[bestIndex], length: bestLen, index: bestIndex };
}

function shortestBar(arr) {
  // returns { bar, length, index }
  let bestIndex = -1;
  let bestLen = Infinity;

  for (let i = 0; i < arr.length; i++) {
    const len = barLength(arr[i]);
    if (len < bestLen) {
      bestLen = len;
      bestIndex = i;
    }
  }

  return bestIndex === -1
    ? null
    : { bar: arr[bestIndex], length: bestLen, index: bestIndex };
}

function darkestBar(arr) {
  // returns { bar, length, index }
  let darkestIndex = -1;
  let darkest = -Infinity;

  for (let i = 0; i < arr.length; i++) {
    const darkness = arr[i][2];
    if (darkness > darkest) {
      darkest = darkness;
      darkestIndex = i;
    }
  }

  return darkestIndex === -1
    ? null
    : { bar: arr[darkestIndex], darkness: darkest, index: darkestIndex };
}

function lightestBar(arr) {
  // returns { bar, length, index }
  let lightestIndex = -1;
  let lightest = Infinity;

  for (let i = 0; i < arr.length; i++) {
    const lightness = arr[i][2];
    if (lightness < lightest) {
      lightest = lightness;
      lightestIndex = i;
    }
  }

  return lightestIndex === -1
    ? null
    : { bar: arr[lightestIndex], darkness: lightest, index: lightestIndex };
}

// For single-phase tasks, which bar is darker? 
export function compareBars(arr1, arr2, firstTask) {
  if (firstTask == "tallest") {
    const bar1 = tallestBar(arr1);
    const bar2 = tallestBar(arr2);
    if ((bar1.length > bar2.length && bar1.bar[2] > bar2.bar[2]) || (bar1.length < bar2.length && bar1.bar[2] < bar2.bar[2])) {
      return ["taller", "darker"];
    } else {
      return ["taller", "lighter"];
    }
  } else if (firstTask == "shortest") {
    const bar1 = shortestBar(arr1);
    const bar2 = shortestBar(arr2);
    if ((bar1.length < bar2.length && bar1.bar[2] > bar2.bar[2]) || (bar1.length > bar2.length && bar1.bar[2] < bar2.bar[2])) {
      return ["shorter", "darker"];
    } else {
      return ["shorter", "lighter"];
    }
  } else if (firstTask == "darkest") {
    const bar1 = darkestBar(arr1);
    const bar2 = darkestBar(arr2);
    if ((bar1.darkness > bar2.darkness && bar1.bar[1] > bar2.bar[1]) || (bar1.darkness < bar2.darkness && bar1.bar[1] < bar2.bar[1])) {
      return ["taller", "darker"];
    } else {
      return ["shorter", "darker"];
    }
  } else if (firstTask == "lightest") {
    const bar1 = lightestBar(arr1);
    const bar2 = lightestBar(arr2);
    if ((bar1.darkness < bar2.darkness && bar1.bar[1] > bar2.bar[1]) || (bar1.darkness > bar2.darkness && bar1.bar[1] < bar2.bar[1])) {
      return ["taller", "lighter"];
    } else {
      return ["shorter", "lighter"];
    }
  }
  throw new Error("firstTask is not specified correctly.");
}

export function compareLongestBars(arr1, arr2) {
  const l1 = longestBar(arr1);
  const l2 = longestBar(arr2);

  if (!l1 || !l2) throw new Error("One of the arrays is empty.");

  if (l1.length > l2.length) return { winner: "arr1", ...l1, other: l2 };
  if (l2.length > l1.length) return { winner: "arr2", ...l2, other: l1 };
  return { winner: "tie", arr1: l1, arr2: l2 };
}

export function compareShortestBars(arr1, arr2) {
  const l1 = shortestBar(arr1);
  const l2 = shortestBar(arr2);

  if (!l1 || !l2) throw new Error("One of the arrays is empty.");

  if (l1.length < l2.length) return { winner: "arr1", ...l1, other: l2 };
  if (l2.length < l1.length) return { winner: "arr2", ...l2, other: l1 };
  return { winner: "tie", arr1: l1, arr2: l2 };
}

export function compareDarkestBars(arr1, arr2) {
  const l1 = darkestBar(arr1);
  const l2 = darkestBar(arr2);

  if (!l1 || !l2) throw new Error("One of the arrays is empty.");

  if (l1.darkness > l2.darkness) return { winner: "arr1", ...l1, other: l2 };
  if (l2.darkness > l1.darkness) return { winner: "arr2", ...l2, other: l1 };
  return { winner: "tie", arr1: l1, arr2: l2 };
}

export function compareLightestBars(arr1, arr2) {
  const l1 = lightestBar(arr1);
  const l2 = lightestBar(arr2);

  if (!l1 || !l2) throw new Error("One of the arrays is empty.");

  if (l1.darkness < l2.darkness) return { winner: "arr1", ...l1, other: l2 };
  if (l2.darkness < l1.darkness) return { winner: "arr2", ...l2, other: l1 };
  return { winner: "tie", arr1: l1, arr2: l2 };
}

