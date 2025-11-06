export function drawBarChart({ 
  values, 
  redIndex, 
  isAnswer,
  label = false, 
  orientation = 'vertical', 
  scale = 1, 
  colorScheme = 'blues',
}) {
  let data = values.map((value, index) => ({
    category: `${index + 1}`,
    start: value[0],
    end: value[1],
    color: value[2] * 100/6,
    layerLow: 1,
    layerHigh: index === redIndex ? 99 : 0
  }));

  if (orientation == "horizontal") data.reverse();

  const axisField = orientation === 'vertical' ? 'x' : 'y';
  const valueField = orientation === 'vertical' ? 'y' : 'x';
  const endField = orientation === 'vertical' ? 'y2' : 'x2';

  const colorPalettes = {
    reds: [
      "rgba(254,224,210,1)","rgba(252,187,161,1)","rgba(252,146,114,1)","rgba(251,106,74,1)","rgba(239,59,44,1)","rgba(203,24,29,1)","rgba(153,0,13,1)"
    ],
    blues: [
      // "rgba(222,235,247,1)","rgba(198,219,239,1)","rgba(158,202,225,1)","rgba(107,174,214,1)","rgba(66,146,198,1)","rgba(33,113,181,1)","rgba(8,69,148,1)"
      "rgba(222,235,247,1)",
      "rgba(198,219,239,1)",
      "rgba(158,202,225,1)",
      "rgba(107,174,214,1)",
      "rgba(66,146,198,1)",
      "rgba(33,113,181,1)",
      "rgba(8,69,148,1)"
    ]
  };

  return {
    "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
    "width": 200 * scale,
    "height": 200 * scale,
    "data": { "values": data },
    "params": [
      {
        "name": "highlightBar",
        "value": `${redIndex + 1}`  // Default: No highlighted bar
      },
      {
        "name": "highlightColor",
        "value": `${isAnswer ? "#6eff76" : "#ffd8d8"}`
      },
      {
        "name": "highlight",
        "value": false
      }
    ],
    "encoding": {
      [axisField]: {
        "sort": null,
        "axis": {
          "title": false,
          "labels": label,
          "ticks": false,
          "grid": false,
          "orient": "bottom"
        }
      },
      [valueField]: {
        "type": "quantitative",
        "axis": {
          "title": false,
          "labels": label,
          "ticks": false,
          "grid": label,
          "tickCount": 10,
          "orient": "left"
        },
        "scale": { 
          "domain": [0, 100]
        }
      },
      "color": {
        "type": "quantitative",
        "scale": {
          "domain": [0, 100],
          "range": colorPalettes[colorScheme] || colorPalettes['reds']
        },
        "legend": null
      }
    },
    "layer": [
      {
        "mark": {"type": "bar", "size": 25},
        "encoding": {
          [axisField]: {"field": "category"},
          [valueField]: {"field": "layerLow"},
          [endField]: {"field": "layerHigh"},
          "color": {
            "condition": {
              "test": "highlight && datum.category === highlightBar",
              "value": {"expr": "highlightColor"}
            },
            "value": "rgba(255,255,255,0)"
          }
        }
      },
      {
        "mark": {"type": "bar", "size": 18},
        "encoding": {
          [axisField]: {"field": "category"},
          [valueField]: {"field": "start"},
          [endField]: {"field": "end"},
          "color": {"field": "color"}
        }
      },
      {
        "data": { 
          "name": "arrowLineLayer"
        },
        "mark": {
          "type": "rule",
          "strokeWidth": 1,
          "color": "black"
        },
        "encoding": {
          [axisField]: {"field": "category", "type": "ordinal"},
          [valueField]: {"field": "arrowLineStart", "type": "quantitative"},
          [endField]: {"field": "arrowLineEnd", "type": "quantitative"}
        }
      },
      {
        "data": {
          "name": "arrowLayer"
        },
        "mark": {
          "type": "point",
          "shape": "triangle",
          "color": "black",
          "size": 100,
          "filled": true
        },
        "encoding": {
          [axisField]: {"field": "category", "type": "ordinal"},
          [valueField]: {"field": "arrowValue", "type": "quantitative"},
          "angle": { "field": "angle", "type": "quantitative", "scale": { "domain": [0, 360] }}
        }
      },
      {
        "data": {
          "name": "textLayer"
          // "values": [{"category": "3", "value": 110, "explanation": "THIS IS A TEST"}]
        },
        "mark": {
          "type": "text",
          "align": "center",
          "clip": false
        },
        "encoding": {
          [axisField]: {"field": "category", "type": "ordinal"},
          [valueField]: {"field": "value", "type": "quantitative"},
          "text": {"field": "explanation"}
        }
      },
    ],
    "config": {
      "view": {
        "clip": false
      }
    }
    // autosize: {
    //   type: "fit",
    //   contains: "padding"
    // }
  };
}