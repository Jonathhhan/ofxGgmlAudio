#include "ofApp.h"

void ofApp::setup() {
	ofSetWindowTitle("ofxGgmlSpeech smoke example");
	request.audioPath = "voice/sample.wav";
	status = ofxGgmlSpeechUtils::describe(request);
	ofLogNotice("ofxGgmlSpeechTranscribeExample") << status;
}

void ofApp::draw() {
	ofBackground(18);
	ofSetColor(240);
	ofDrawBitmapString("ofxGgmlSpeech", 32, 48);
	ofDrawBitmapString(status, 32, 78);
}