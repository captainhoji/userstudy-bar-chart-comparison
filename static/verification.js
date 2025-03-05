jsVerification = document.getElementById("jsVerification");
jsVerified = document.getElementById("jsVerified");
cookieVerification = document.getElementById("cookieVerification");
cookieVerified = document.getElementById("cookieVerified");
plusButton = document.getElementById("plusButton");
minusButton = document.getElementById("minusButton");
creditCardSVG = document.getElementById("creditCardSVG");
creditCardRect = document.getElementById("creditCardRect");

verifyJS();
verifyCookies();

localStorage.setItem("width", 312);
localStorage.setItem("height", 200);
localStorage.setItem("scale", 1.0);
creditCardSize(1);

function creditCardSize(scale) {
	const height = localStorage.getItem("height")*scale;
	const width = localStorage.getItem("width")*scale;
        localStorage.setItem("height", height);
        localStorage.setItem("width", width);

	creditCardSVG.setAttribute("height", height);
	creditCardSVG.setAttribute("width", width);
	creditCardRect.setAttribute("height", height);
        creditCardRect.setAttribute("width", width);
        
        const currScale = localStorage.getItem("scale");
        localStorage.setItem("scale", scale * currScale);
}

plusButton.onclick = function() {
	creditCardSize(1.05);
}

minusButton.onclick = function() {
	creditCardSize(0.95);
}

function verifyJS() {
	jsVerification.style.visibility = "hidden";
	jsVerification.style.position = "absolute";
	jsVerified.style.visibility = "visible";
	jsVerified.style.position = "static";
	jsVerified = true;
}

function verifyCookies() {
        if (navigator.cookieEnabled) {
		cookieVerification.style.visibility = "hidden";
        	cookieVerification.style.position = "absolute";
        	cookieVerified.style.visibility = "visible";
        	cookieVerified.style.position = "static";
        	if (jsVerified) {
			document.getElementById("readyButton").style.visibility = "visible";
		}
	}
}
