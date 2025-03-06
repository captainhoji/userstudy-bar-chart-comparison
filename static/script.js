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
    orientation = data.orientation;
    whatToAlterFirst = data.whatToAlterFirst;
    stimuli = data.stimuli;
    practices_easy = data.practice_easy;
    numbers = data.numbers

    blockCounter = 0;

    console.log("task: ", task)    
    console.log("label: ", label)
    console.log("orientation: ", orientation)
    console.log("whatToAlterFirst: ", whatToAlterFirst)
    console.log("stimuli: ", stimuli)
    // console.log("practices: ", practices)
    console.log("numbers: ", numbers)


    instructionText = `<p>This experiment consists of 4 sections.<br>
        Each section will include a few practice trials followed by 20 real trials.<br><br>
        On each trial, you will be presented with two bar charts and you will be asked to <strong>`

    if (task == "compare_highest") {
        instructionText += 'find the bar chart that has the highest bar</strong>.'
    } else if (task == "compare_index") {
        instructionText += 'find the highest bar from each chart, and report which one is closer to the right side of its chart</strong>.'
    }

    instructionText += '<br><br>Your task will be the same for all 4 sections of the experiment, but the charts and response buttons will be different.'
    instructionText += '<br><br>Please press the spacebar to see the instructions for section 1.</p>'

    document.getElementById("instruction-text").innerHTML = instructionText;

    document.addEventListener("keydown", handleSpacePress(() => loadInstructions(blockCounter, practice=true, easyPractice=true)));

    // loadInstructions(blockCounter, practice=true, easyPractice=true);
    // loadTrial(participantId)
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
        if (task === "compare_highest") {
            if (currentLayout === 'horizontal') {
                instructionText += `In this section of the experiment you will be presented with 
                    two charts side by side. 
                    Your task is to <strong>report which chart has the highest bar</strong>. `;
            } else {
                instructionText += `In this section of the experiment you will be presented with 
                    two charts arranged one above the other. 
                    Your task is to <strong>report which chart has the highest bar</strong>. `;
            }
        } else if (task === "compare_index") {
            if (currentLayout === 'horizontal') {
                instructionText += `In this section of the experiment you will be presented with 
                    two charts side by side. `;
            } else {
                instructionText += `In this section of the experiment you will be presented with 
                    two charts arranged one above the other. `;
            }
            instructionText += `Your task is to find the highest bar from each chart, and report which one is closer to the right side of its chart. `
        }

        if (currentLayout === 'horizontal') {
            instructionText += `To respond, please press the left or right arrow key. `;
        } else {
            instructionText += `To respond, please press the up or down arrow key. `;
        }
        instructionText += "<br><br>";

        if (task === "compare_highest") {
            if (currentLayout === "horizontal") {
                instructionText += `In the example below, the highest bar is located in the chart on the RIGHT, 
                so you would press the RIGHT ARROW KEY. `;
                if (!currentLabel) {
                    instructionText += `<img src="static/img/compare_height_horizontal_unlabeled.png" width="400px">`
                } else {
                    instructionText += '<img src="static/img/compare_height_horizontal_labeled.png" width="400px">'
                }
            } else {
                instructionText += `In the example below, the highest bar is located in the chart at the BOTTOM, 
                so you would press the DOWN ARROW KEY. `;
                if (!currentLabel) {
                    instructionText += '<img src="static/img/compare_height_vertical_unlabeled.png" height="400px">'
                } else {
                    instructionText += '<img src="static/img/compare_height_vertical_labeled.png" height="400px">'
                }
            }
        } else {
            if (currentLayout === "horizontal") {
                instructionText += `In the example below, the highest bar of the LEFT chart is closer to the right side of its chart than
                    the highest bar of the RIGHT chart is. So, you would press the <b>LEFT</b> ARROW KEY. <b>(The fact that the RIGHT chart has the higher bar does not matter.)</b> `;
                if (!currentLabel) {
                    instructionText += '<img src="static/img/compare_index_horizontal_unlabeled.png" width="400px">'
                } else {
                    instructionText += '<img src="static/img/compare_index_horizontal_labeled.png" height="400px">'
                }
            } else {
                instructionText += `In the example below, the highest bar of the TOP chart is closer to the right side of its chart than
                    the highest bar of the BOTTOM chart is. So, you would press the <b>UP</b> ARROW KEY. <b>(The fact that the BOTTOM chart has the higher bar does not matter.)</b> `;
                if (!currentLabel) {
                    instructionText += '<img src="static/img/compare_index_vertical_unlabeled.png" height="400px">'
                } else {
                    instructionText += '<img src="static/img/compare_index_vertical_labeled.png" height="400px">'
                }
            }
        }

        instructionText += 'Please indicate your answer as ACCURATELY and as QUICKLY as possible. <br/><br/>'

        instructionText += `You will be asked to complete basic practice trials to get familiar with the task.
            <br>You will need to get <b>five correct trials in a row</b> to proceed.
            <br>Please make sure you understand the instructions before continuing!
            <br>Please press the spacebar to start the practice trials.</p>`;
    // actual task instructions
    } else if (practice) {
        titleContainer.textContent = `Section ${blockCounter+1} of 4: Practice Trials`;

        instructionText += `Now you will complete 8 harder practice trials which closely resemble the real trials.`;
        // instructionText += '<br>You have to get at least <b>7 out of 8 correct</b> to move on to the real trials.'
        if (task === "compare_highest") {
            instructionText += '<br><br> Again, your task is to report which chart has the highest bar. ';
        } else {
            instructionText += "<br><br> Again, your task is to report which chart's highest bar is closer to the right side of its chart. ";
        }
        instructionText += '<br/><br/> Please indicate your answer as ACCURATELY and as QUICKLY as possible.<br/><br/>';
        instructionText += `</p><h3>Press the spacebar to start the 8 practice trials.</h3>`;
    } else {
        titleContainer.textContent = `Section ${blockCounter+1} of 4: Real Trials`;

        instructionText += `You got ${practiceCorrects} out of ${blockLength} correct.`;
        instructionText += `<br><br>Please remember that <b>accuracy</b> is just as important as speed!`;
        instructionText += `<br><br>Now you will complete the real trials. There are 20 real trials.`;

        // if (task === "compare_highest") {
        //     instructionText += '<br><br> Again, your task is to report which chart has the highest bar. '
        // } else {
        //     instructionText += "<br><br> Again, your task is to report which chart's highest bar is closer to the right side of its chart. "
        // }
        // instructionText += '<br/><br/> Again, indicate your answer as ACCURATELY and as QUICKLY as possible.<br/><br/>'
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
        answer = data[2]

        if (task === "compare_index") {
            let modData = null;
            if (trialCounter % 3 == 0) {
                modData = data;
            } else if (trialCounter % 3 == 1) {
                modData = [...data];
                const maxIndex = modData[2-data[2]].indexOf(Math.max(...modData[2-data[2]]));
                modData[2-data[2]][maxIndex] -= 10;
            } else {
                modData = [...data];
                const maxIndex = modData[data[2]-1].indexOf(Math.max(...modData[data[2]-1]));
                modData[data[2]-1][maxIndex] -= 10;
            }
            displayCrosshair(500, () => displayCharts(modData));
        } else {
            displayCrosshair(500, () => displayCharts(data));
        }
    } else {
        if (isPractice) {
            console.log(`loading practice trial ${trialCounter+1} of block ${blockCounter+1}`)
        } else {
            console.log(`loading trial ${trialCounter+1} of block ${blockCounter+1}`)
        }
        data = stimuliBlock[trialCounter];
        if (task == 'compare_highest') {
            answer = data[2]
        } else {
            answer = data[3]
        }
        displayCrosshair(500, () => displayCharts(data));
    }
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
                top: 5%;             /* Adjust this value as needed */
                font-size: 20px;
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
                max-width: 60%;
            ">
            </p>
        </div>
    `;

    const chartSpec1 = drawBarChart('chart1', data[0], currentLabel);
    const chartSpec2 = drawBarChart('chart2', data[1], currentLabel);

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

function drawBarChart(elementId, values, label) {
    const data = values.map((value, index) => ({
        category: String.fromCharCode(49 + index),
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
            "value": "none"  // Default: No highlighted bar
          },
          {
            "name": "highlightColor",
            "value": "black"
          }
        ],
        "encoding": {
            "x": {
                "field": "category",
                "axis": {
                    "title": false,
                    "labels": label,     // Remove axis labels
                    "ticks": label,      // Remove axis ticks
                    // "domain": false,     // Remove axis line
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
                    // "domain": false,     // Remove axis line
                    "grid": false,        // Remove gridlines
                    "tickCount": 10,
                    "labelFontSize": 15*scale,
                    "orient": "left"
                },
                "scale": { "domain": [0, 100] }
            },
            "color": {
                "condition": {
                    "test": "datum.category === highlightBar",
                    "value": {"expr": "highlightColor"}
                },
                "value": "black"
            }
        },
        "config": {
            "view": {
                "stroke": "transparent"
            }
        }
    };

    return chartSpec
}

function updateBarColor(chart_i, bar_i, newColor) {
    const view = chart_i === 1 ? chartView1 : chartView2;
    if (view) {
        view.signal("highlightBar", String.fromCharCode(49 + bar_i)).run();  // Correctly update parameter
        view.signal("highlightColor", newColor).run();  // Correctly update color parameter
    }
}

async function saveResponse(participantId, response) {
    const duration = stopTimer();
    const isCorrect = response == answer ? true : false
    stimuliBeingShown = false;

    if (isEasyPractice) {
        const explanationContainer = document.getElementById('explanation');
        // data[0] and data[1] are arrays, data[2] is answer
        let explanation = ""
        const maxIndex1 = data[0].indexOf(Math.max(...data[0]));
        const maxIndex2 = data[1].indexOf(Math.max(...data[1]));
        const answer = data[2]
        const direction1 = currentLayout === "horizontal" ? "left" : "top";
        const direction2 = currentLayout === "horizontal" ? "right" : "bottom";
        const correctDirection = currentLayout === "horizontal" ? (answer === 1 ? "left" : "right") : (answer === 1 ? "top" : "bottom");
        const incorrectDirection = currentLayout === "horizontal" ? (answer === 1 ? "right" : "left") : (answer === 1 ? "bottom" : "top");
        if (task === "compare_highest") {
            updateBarColor(answer, answer == 1 ? maxIndex1 : maxIndex2, "green");
            explanation += `The answer is the ${correctDirection} chart because it has the highest bar. `; 
            // color the highest bar
        } else {
            updateBarColor(answer, answer == 1 ? maxIndex1 : maxIndex2, "green");
            updateBarColor(3-answer, answer == 1 ? maxIndex2 : maxIndex1, "grey");
            explanation += `The answer is the <b>${correctDirection}</b> chart because the green bar is closer to the right side of its chart than is the grey bar. `
            // `Because ${answer == 1 ? maxIndex1+1 : maxIndex2+1} is bigger than ${answer == 1 ? maxIndex2+1 : maxIndex1+1}, the answer is the ${correctDirection} chart. `;
            if (trialCounter % 3 == 2) {
                explanation += `<br><b>(The fact that the ${incorrectDirection} chart has the highest bar does not matter.)</b>`
            }
        }
        explanation += '<br>Please press the spacebar for the next trial.';
        
        const fontColor = isCorrect ? "green" : "red";
        explanation = `<b><font color="${fontColor}">${isCorrect ? "Correct" : "Incorrect"}!</font></b><br>` + explanation
        
        explanationContainer.innerHTML = explanation;
        // const feedbackContainer = document.getElementById('controls-instruction');
        // feedbackContainer.textContent = isCorrect ? "Correct" : "Incorrect";
        // feedbackContainer.style.color = isCorrect ? "green" : "red";
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
                orientation: currentLayout,
                label: currentLabel,
                stimuli: [stimuli[blockCounter][trialCounter][0], stimuli[blockCounter][trialCounter][1]],
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
            if (consecutivePracticeCorrects >= 5 || trialCounter >= practices_easy.length) {
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
                        // window.location.href = `/follow_up?participant_id=${participantId}`;
                        window.location.href = `/thank_you`;
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
        if (task === "compare_highest") {
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
