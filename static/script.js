let cachedData = null;
let answer = null;
let blockCounter = 0;
let trialCounter = 0;
let currentLayout = 'horizontal';
let currentLabel = false;
let task = null;
let label = null;
let orientation = null;
let whatToAlterFirst = null;
let stimuli = null;
let practices = null;
let practices_easy = null;
let numbers = null;
let stimuliBlock = null;
let startTime = null;
let blockLength = 0;
let stimuliBeingShown = false;
let hideChartTimeout;
let isPractice = true;
let consecutivePracticeCorrects = 0;
let practiceCorrects = 0;
let isEasyPractice = true;
let chartView1 = null;
let chartView2 = null;
const T = 2;

async function initializeStudy(participantId) {
    const response = await fetch('/initialize_task', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ participant_id: participantId, message: "initialize"})
    });
    const data = await response.json();
    cachedData = data;

    task = data.task;
    label = data.label;
    orientation = data.layout;
    stimuli = data.stimuli;
    practices_easy = data.practice_easy;
    numbers = data.numbers

    blockCounter = 0;

    console.log("task: ", task)    
    console.log("label: ", label)
    console.log("orientation: ", orientation)
    console.log("stimuli: ", stimuli)
    console.log("numbers: ", numbers)


    instructionText = `<p>This experiment consists of 4 sections.<br>
        Each section will include a few practice trials followed by around 30 real trials.<br><br>
        On each trial, you will be presented with two bar charts. Each bar chart will have one red bar. You will be asked to <strong>`

    if (task == "compare_height") {
        instructionText += 'identify which red bar is taller</strong>.'
    } else if (task == "compare_index") {
        instructionText += 'identify which red bar is positioned farther to the right</strong>.'
    }

    instructionText += '<br><br>Please press the spacebar to see the instructions for section 1.</p>'

    document.getElementById("instruction-text").innerHTML = instructionText;

    document.addEventListener("keydown", handleSpacePress(() => loadInstructions(blockCounter, practice=true, easyPractice=true)));
}

function loadInstructions(blockCounter, practice=true, easyPractice=false) {
    const titleContainer = document.getElementById('section-title');
    const chartContainer = document.getElementById('chart-container');
    chartContainer.style.display = "none";

    const instructionOverlay = document.getElementById('instruction-overlay');
    instructionOverlay.style.display = "flex";

    trialCounter = 0;
    currentLabel = label[blockCounter];
    currentLayout = orientation[blockCounter];
    
    let instructionText = "<p>";
    // practice task instructions
    if (easyPractice) {
        titleContainer.textContent = `Section ${blockCounter+1} of 4: Instructions`
        if (task === "compare_height") {
            if (currentLayout === 'horizontal') {
                instructionText += `In this section of the experiment you will be presented with 
                    two bar charts side by side. Each chart have one red bar.`;
            } else {
                instructionText += `In this section of the experiment you will be presented with 
                    two bar charts arranged one above the other. `;
            }
            instructionText += `Your task is to <strong>identify which red bar is taller</strong>. `;
        } else if (task === "compare_index") {
            if (currentLayout === 'horizontal') {
                instructionText += `In this section of the experiment you will be presented with 
                    two bar charts side by side. `;
            } else {
                instructionText += `In this section of the experiment you will be presented with 
                    two bar charts arranged one above the other. `;
            }
            instructionText += `Your task is to <strong>identify which red bar is positioned farther to the right</strong>. `
        }

        if (currentLayout === 'horizontal') {
            instructionText += `To respond, please press the left or right arrow key. `;
        } else {
            instructionText += `To respond, please press the up or down arrow key. `;
        }
        instructionText += "<br><br>";

        if (task === "compare_height") {
            if (currentLayout === "horizontal") {
                instructionText += `In the example below, the red bar of the RIGHT chart is taller, 
                so you would press the RIGHT ARROW KEY. `;
                if (!currentLabel) {
                    instructionText += `<img src="static/img/compare_height_horizontal_unlabeled.png" width="400px">`
                } else {
                    instructionText += '<img src="static/img/compare_height_horizontal_labeled.png" width="400px">'
                }
            } else {
                instructionText += `In the example below, the red bar of the BOTTOM chart is taller, 
                so you would press the DOWN ARROW KEY. `;
                if (!currentLabel) {
                    instructionText += '<img src="static/img/compare_height_vertical_unlabeled.png" height="400px">'
                } else {
                    instructionText += '<img src="static/img/compare_height_vertical_labeled.png" height="400px">'
                }
            }
        } else {
            if (currentLayout === "horizontal") {
                instructionText += `In the example below, the red bar on the LEFT is positioned farther to the right within its chart. So, you would press the <b>LEFT</b> ARROW KEY. <b>(The heights of red bars do not matter.)</b> `;
                if (!currentLabel) {
                    instructionText += '<img src="static/img/compare_index_horizontal_unlabeled.png" width="400px">'
                } else {
                    instructionText += '<img src="static/img/compare_index_horizontal_labeled.png" height="400px">'
                }
            } else {
                instructionText += `In the example below, the red bar on the BOTTOM is positioned farther to the right within its chart. So, you would press the <b>DOWN</b> ARROW KEY. <b>(The heights of red bars do not matter.)</b> `;
                if (!currentLabel) {
                    instructionText += '<img src="static/img/compare_index_vertical_unlabeled.png" height="400px">'
                } else {
                    instructionText += '<img src="static/img/compare_index_vertical_labeled.png" height="400px">'
                }
            }
        }

        instructionText += 'Please indicate your answer as ACCURATELY and as QUICKLY as possible. <br/><br/>'

        instructionText += `You will be asked to complete practice trials to get familiar with the task. You need to get <b>5 correct in a row</b> to proceed.
            <br>Please make sure you understand the instructions. Please press the spacebar to start the practice trials.</p>`;
    // actual task instructions
    } else if (practice) {
        titleContainer.textContent = `Section ${blockCounter+1} of 4: Practice Trials`;

        instructionText += `Now you will complete 8 harder practice trials which closely resemble the real trials.`;
        instructionText += 'You do not need to press the spacebar in this section. The trials will advance automatically. '
        if (task === "compare_height") {
            instructionText += '<br><br> Again, your task is to identify which red bar is higher. ';
        } else {
            instructionText += "<br><br> Again, your task is to identify which red bar is positioned farther to the right. ";
        }
        instructionText += '<br/><br/> Please indicate your answer as ACCURATELY and as QUICKLY as possible.<br/><br/>';
        instructionText += `</p><h3>Press the spacebar to start the 8 practice trials.</h3>`;
    } else {
        titleContainer.textContent = `Section ${blockCounter+1} of 4: Real Trials`;

        instructionText += `You got ${practiceCorrects} out of ${blockLength} correct.`;
        instructionText += `<br><br>Please remember that <b>accuracy</b> is just as important as speed!`;
        instructionText += `<br><br>Now you will complete the real trials. There are around 30 real trials.`;
        instructionText += '<br>You do not need to press the spacebar in this section. The trials will advance automatically. '
        instructionText += `</p><h3>Press the spacebar to start the real trials.</h3>`;
    }

    document.getElementById("instruction-text").innerHTML = instructionText;

    isEasyPractice = easyPractice;
    isPractice = practice;
    if (practice) {
        if (easyPractice) {
            shuffle(practices_easy);
            consecutivePracticeCorrects = 0;
        } else {
            getPractice();
        }
    } else {
        stimuliBlock = stimuli[blockCounter];
        blockLength = stimuliBlock.length;
    }

    console.log("currentLabel: ", currentLabel)
    console.log("currentLayout: ", currentLayout)

    document.addEventListener("keydown", handleSpacePress(loadTrial));
    document.removeEventListener('keydown', handleKeyPress);    // Remove any existing keydown event listeners to prevent duplicates
    document.addEventListener('keydown', handleKeyPress);
}

function handleSpacePress(callback) {
    return function eventHandler(event) {
        if (event.code === "Space") {
            document.removeEventListener("keydown", eventHandler); // Remove event listener after first press
            callback();
        }
    };
}

function handleKeyPress(event) {
    if (!stimuliBeingShown) return;
    if (currentLayout === 'horizontal') {
        if (event.key === 'ArrowLeft') {
            saveResponse(participantId, "1");
        } else if (event.key === 'ArrowRight') {
            saveResponse(participantId, "2");
        }
    } else if (currentLayout === 'vertical') {
        if (event.key === 'ArrowUp') {
            saveResponse(participantId, "1");
        } else if (event.key === 'ArrowDown') {
            saveResponse(participantId, "2");
        }
    }
}

async function loadTrial() {
    const instructionOverlay = document.getElementById('instruction-overlay');
    instructionOverlay.style.display = "none";
    if (isEasyPractice) {
        console.log(`loading easy practice trial ${trialCounter+1}`);
        data = practices_easy[trialCounter];
    } else {
        if (isPractice) {
            console.log(`loading practice trial ${trialCounter+1} of block ${blockCounter+1}`)
        } else {
            console.log(`loading trial ${trialCounter+1} of block ${blockCounter+1}`)
        }
        data = stimuliBlock[trialCounter];
    }
    answer = task === "compare_height" ? data[2] : data[3]
    displayCrosshair(500, () => displayCharts(data));
}

function displayCrosshair(duration, callback) {
    const container = document.getElementById('chart-container');
    container.style.display = 'flex';
    container.innerHTML = `
        <div id="crosshair" style="
            display: flex;
            justify-content: center;
            align-items: center;
            width: 100vw;
            height: 100vh;
            font-size: 50px;
            font-weight: bold;
            color: black;
            background-color: white;
        ">+</div>
    `;

    setTimeout(() => {
        container.innerHTML = ""; // Remove crosshair
        if (callback) callback(); // Show next trial
    }, duration);
}

function displayCharts(data) {
    const container = document.getElementById('chart-container');

    // Set the flex direction based on layout (horizontal vs vertical)
    const layoutStyle = currentLayout === 'horizontal' ? 'row' : 'column';

    let scale = localStorage.getItem("scale");
    container.innerHTML = `
        <div style="
            display: flex; 
            flex-direction: column;
            justify-content: center;  /* Center content horizontally */
            align-items: center;      /* Center content vertically */
            height: 100vh;            /* Full viewport height */
            width: 100vw;             /* Full viewport width */
        ">
            <p id="controls-instruction" style="
                position: absolute;
                top: 3%;             /* Adjust this value as needed */
                font-size: 16px;
                text-align: center;
                width: 100%;
            ">
                Respond using the ${currentLayout === "horizontal" ? "left" : "up"} or ${currentLayout === "horizontal" ? "right" : "down"} arrow key
            </p>
            <div style="
                display: flex; 
                flex-direction: ${layoutStyle}; 
                gap: ${currentLayout === "horizontal" ? 100 : 50}px; 
                align-items: center;   /* Ensures charts are centered horizontally */
                justify-content: center; /* Ensures charts are centered vertically */
                max-width: 90%;         /* Limits width to prevent excessive stretching */
                max-height: 90%;
                width: 100%;
                transform-origin: center;    /* Keep scaling centered */
            ">
                <div id="chart1" style="
                    display: inline-block; /* Ensures div only takes as much space as its content */
                    width: fit-content; 
                    height: fit-content; 
                    overflow: visible; /* Ensures content is not clipped */">
                </div>
                <div id="chart2" style="
                    display: inline-block; /* Ensures div only takes as much space as its content */
                    width: fit-content; 
                    height: fit-content; 
                    overflow: visible; /* Ensures content is not clipped */">
                </div>
            </div>
            <div id="explanation" style="
                position: absolute;
                top: 90%;             /* Adjust this value as needed */
                font-size: 20px;
                text-align: center;
                max-width: 80%;
            ">
            </p>
        </div>
    `;

    const chartSpec1 = drawBarChart('chart1', data[0], data[4][0], currentLabel);
    const chartSpec2 = drawBarChart('chart2', data[1], data[4][1], currentLabel);

    Promise.all([
        vegaEmbed('#chart1', chartSpec1, {"actions": false}).then(result => {
            chartView1 = result.view;  // Save the Vega view object
        }),    
        vegaEmbed('#chart2', chartSpec2, {"actions": false}).then(result => {
            chartView2 = result.view;  // Save the Vega view object
        })
    ]).then(() => {
        stimuliBeingShown = true;
        startTimer();  // Start the timer only after the chart is fully loaded

        // hideChartTimeout = setTimeout(() => {
        //     container.style.display = 'none'; // Hide the chart container
        // }, T*1000);
    })
}

function drawBarChart(elementId, values, redIndex, label) {
    const data = values.map((value, index) => ({
        category: `${index+1}`,
        value: value
    }));

    let scale = localStorage.getItem("scale");
    const chartSpec = {
        "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
        "width": 200*scale,
        "height": 200*scale,
        "data": {
            "values": data
        },
        "mark": "bar",
        "params": [
            {
                "name": "highlightBar",
                "value": `${redIndex+1}`
            },
            {
                "name": "highlightColor",
                "value": "red"  // Highlight color is red
            }
        ],
        "encoding": {
            "x": {
                "field": "category",
                "sort": null,  // Prevents automatic sorting of x-axis categories
                "axis": {
                    "title": false,
                    "labels": label,     // Remove axis labels
                    "ticks": label,      // Remove axis ticks
                    "grid": false,        // Remove gridlines
                    "labelAngle": 0,
                    "labelFontSize": 15*scale,
                    "orient": "bottom"
                }
            },
            "y": { 
                "field": "value",
                "type": "quantitative",
                "axis": {
                    "title": false,
                    "labels": label,     // Remove axis labels
                    "ticks": label,      // Remove axis ticks
                    "grid": label,        
                    "tickCount": 10,
                    "labelFontSize": 15*scale,
                    "orient": "left"
                },
                "scale": { "domain": [0, 100] }
            },
            "color": {
                "condition": {
                    "test": "datum.category === highlightBar",
                    "value": {"expr": "highlightColor"}  // Highlights one bar in red
                },
                "value": "black"  // Default bar color
            },
        },
        "config": {
            "view": {
                "stroke": "transparent"
            }
        }
    };

    return chartSpec
}

// function updateBarColor(chart_i, bar_i, newColor) {
//     const view = chart_i === 1 ? chartView1 : chartView2;
//     if (view) {
//         view.signal("highlightBar", String.fromCharCode(49 + bar_i)).run();  // Correctly update parameter
//         view.signal("highlightColor", newColor).run();  // Correctly update color parameter
//     }
// }

async function saveResponse(participantId, response) {
    const duration = stopTimer();
    const isCorrect = response == answer ? true : false
    stimuliBeingShown = false;

    if (isEasyPractice) {
        const explanationContainer = document.getElementById('controls-instruction');
        // const explanationContainer = document.getElementById('explanation');
        let explanation = ""
        const answer = task === "compare_height" ? data[2] : data[3]
        const direction1 = currentLayout === "horizontal" ? "left" : "top";
        const direction2 = currentLayout === "horizontal" ? "right" : "bottom";
        const correctDirection = currentLayout === "horizontal" ? (answer === 1 ? "left" : "right") : (answer === 1 ? "top" : "bottom");
        const incorrectDirection = currentLayout === "horizontal" ? (answer === 1 ? "right" : "left") : (answer === 1 ? "bottom" : "top");
        if (task === "compare_height") {
            explanation += `The answer is the <b>${correctDirection}</b> chart because its red bar is higher than the red bar of the ${incorrectDirection} chart. `; 
        } else {
            explanation += `The answer is the <b>${correctDirection}</b> chart because its red bar is closer to the right side of its chart than the red bar of the ${incorrectDirection} chart. `;
        }
        explanation += '<br>Please press the <b>spacebar</b> for the next trial.';
        
        const fontColor = isCorrect ? "green" : "red";
        explanation = `<b><font color="${fontColor}">${isCorrect ? "Correct" : "Incorrect"}!</font></b><br>` + explanation
        
        explanationContainer.innerHTML = explanation;

    } else {
        // Show full-screen feedback
        const feedbackOverlay = document.getElementById('feedback-overlay');
        feedbackOverlay.textContent = isCorrect ? "Correct" : "Incorrect";
        feedbackOverlay.style.color = isCorrect ? "green" : "red";
        feedbackOverlay.style.display = "flex"; // Make overlay visible
    }

    // clearTimeout(hideChartTimeout);

    if (!isPractice) {
        if (!participantId) {
            participantId = localStorage.getItem("participantId");
        }
        const now = new Date();
        fetch('/save_response', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ 
                participant_id: participantId,
                task: task, 
                response: response, 
                correct: response == answer ? 1 : 0, 
                order: trialCounter,
                time_when: now,
                layout: currentLayout,
                label: currentLabel,
                number: numbers[blockCounter][trialCounter],
                duration: duration
            })
        });
    }
    trialCounter += 1;
    if (isEasyPractice) {
        if (isCorrect) {
            consecutivePracticeCorrects += 1;
        } else {
            consecutivePracticeCorrects = 0;
        }
    } else if (isPractice) {
        if (isCorrect) {
            practiceCorrects += 1;
        }
    }

    if (isEasyPractice) {
        document.addEventListener("keydown", handleSpacePress(handleNextTrialLoad));
    } else {
        handleNextTrialLoad()
    }

}

function handleNextTrialLoad() {
// Hide after 500ms and load next trial
    setTimeout(() => {
        if (isEasyPractice) {
            if (consecutivePracticeCorrects >= 5 || trialCounter > 30) {
                isEasyPractice = false;
                if (trialCounter >= practices_easy.length) {
                    if (!participantId) {
                        participantId = localStorage.getItem("participantId");
                    }
                    fetch('/save_practiceFail', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ 
                            participant_id: participantId,
                            task: task, 
                            orientation: currentLayout,
                            label: currentLabel
                        })
                    });
                }
                loadInstructions(blockCounter, practice=true);
            } else {
                loadTrial();
            }
        } else {
            const feedbackOverlay = document.getElementById('feedback-overlay');
            feedbackOverlay.style.display = "none"; // Hide overlay
            if (trialCounter < blockLength) {
                loadTrial();
            } else {
                if (isPractice) { // practice session finished
                    showPracticeResults(); // display practice results page
                } else {
                    blockCounter += 1
                    if (blockCounter == 4) { // all 4 blocks completed
                        if (!participantId) {
                            participantId = localStorage.getItem("participantId");
                        }
                        window.location.href = `/follow_up?participant_id=${participantId}`;
                        // window.location.href = `/thank_you`;
                    } else {
                        loadInstructions(blockCounter, practice=true, easyPractice=true)
                    }                
                }
            }
        }
    }, isEasyPractice ? 0 : 500);
}

function showPracticeResults() {
    const feedbackOverlay = document.getElementById('feedback-overlay');
    feedbackOverlay.style.display = "flex"; // Hide overlay
    feedbackOverlay.style.color = "black";

    let feedbackText = `You got ${practiceCorrects} out of ${blockLength} correct.`
    if (practiceCorrects >= 0) {
        // feedbackText += '<br><br> Good job! Keep up the good work!'
        // feedbackText += '<br> ';
        // feedbackText += '<br><br> Please press the spacebar to continue.';
        // document.addEventListener("keydown", handleSpacePress(() => {
        //     document.getElementById('feedback-overlay').style.display = "none";
        //     loadInstructions(blockCounter, false);
        // }));
        document.getElementById('feedback-overlay').style.display = "none";
        loadInstructions(blockCounter, false)
    } else {
        feedbackText += '<br><br> You have to get at least 7 out of 8 correct to move on to the real trials. ' 
        if (task === "compare_height") {
            feedbackText += "<br><br> Again, your task is to report which chart has the highest bar. "
        } else {
            feedbackText += "<br><br> Again, your task is to report which chart's highest bar is closer to the right side of its chart. "
        }
        feedbackText += '<br> Please press the spacebar to start another round of practice.'
        getPractice();
        document.addEventListener("keydown", handleSpacePress(() => {
            document.getElementById('feedback-overlay').style.display = "none";
            loadTrial();
        }));
    }
    feedbackOverlay.innerHTML = feedbackText;
}

function getPractice() {
    fetch('/get_practice', {
        method: 'GET',
        headers: { 'Content-Type': 'application/json' },
    })
    .then(response => response.json())
    .then(data => {
        stimuliBlock = data.practice;
        blockLength = stimuliBlock.length;
    })
    .catch(error => console.error('Error:', error));
    practiceCorrects = 0;
    trialCounter = 0;
}


function startTimer() {
    startTime = performance.now();  // More accurate than Date.now()
}

// Function to stop recording time and calculate duration
function stopTimer() {
    let endTime = performance.now();
    let duration = endTime - startTime;  // Convert to seconds
    console.log("Duration:", duration.toFixed(2), "ms");
    return duration
}

function shuffle(arr) {
    var j, x, index;
    for (index = arr.length - 1; index > 0; index--) {
        j = Math.floor(Math.random() * (index + 1));
        x = arr[index];
        arr[index] = arr[j];
        arr[j] = x;
    }
}
