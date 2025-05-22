/**
    (C) 2022 - ntop.org
*/

import {ntopng_utility} from '../../services/context/ntopng_globals_services.js';


/* ***************************************** */

function transformColors(colors) {
  const colorsPositionDict = {};
  colors.forEach((c, i) => {
    if (colorsPositionDict[c] == null) {
	    colorsPositionDict[c] = [i];
    } else {
	    colorsPositionDict[c].push(i);
    }
  });
  // clone colors
  const newColors = ntopng_utility.clone(colors);

  for (const color in colorsPositionDict) {
    const colorsPosition = colorsPositionDict[color];
    const n = colorsPosition.length;
    // colorsGenerated.length == colorsPosition.length always true
    const colorsGenerated = getColorsFromColor(color, n);
    colorsGenerated.forEach((c, i) => {
	    const cPosition = colorsPosition[i];
	    newColors[cPosition] = c;
    });
  }
  return newColors;
}

/* ***************************************** */

function getColorsFromColor(color, n) {
  return [...Array(n).keys()].map((c, i) => {
    return generateColor(color, i + 1, n);
  });
}

/* ***************************************** */

/**
 * Generate a color that represent the index-th tint of n of baseColor.
 * @param {baseColor} string color in hex format.
 * @param {index} integer in interval [1, n].
 * @param {n} total number of colors to generate
**/
function generateColor(baseColor, index, n) {
  const sourceColor = baseColor.replace('#', '');

  const redSource = parseInt(sourceColor.substring(0, 2), 16);
  const greenSource = parseInt(sourceColor.substring(2, 4), 16);
  const blueSource = parseInt(sourceColor.substring(4, 6), 16);

  const cRed = getColorInterpolation(redSource, index, n);
  const cGreen = getColorInterpolation(greenSource, index, n);
  const cBlue = getColorInterpolation(blueSource, index, n);

  return rgbToHex(cRed, cGreen, cBlue);
}

/* ***************************************** */

function getColorInterpolation(colorSource, i, n) {
  if (n <= 1) {
    return colorSource;
  }
  const colorStart = Math.trunc(colorSource / 2);
  const colorEnd = Math.trunc(colorSource + ((255 - colorSource) / 2));
  const interval = Math.trunc((colorEnd - colorStart) / n);

  return colorStart + i * interval;
  // return colorStart + (n - i) * interval;
}

/* ***************************************** */

function rgbToHex(r, g, b) {
  return '#' + componentToHex(r) + componentToHex(g) + componentToHex(b);
}

/* ***************************************** */

function componentToHex(c) {
  const hex = c.toString(16);
  return hex.length == 1 ? '0' + hex : hex;
}

/* ***************************************** */

const colorsInterpolation = function() {
  return {
	    transformColors,
  };
}();

export default colorsInterpolation;
