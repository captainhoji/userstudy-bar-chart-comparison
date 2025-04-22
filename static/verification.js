jsVerification = document.getElementById("jsVerification");
jsVerified = document.getElementById("jsVerified");
cookieVerification = document.getElementById("cookieVerification");
cookieVerified = document.getElementById("cookieVerified");
plusButton = document.getElementById("plusButton");
minusButton = document.getElementById("minusButton");

verifyJS();
verifyCookies();

localStorage.setItem("width", 312);
localStorage.setItem("height", 200);
localStorage.setItem("scale", 1.0);

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
