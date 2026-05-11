#include "ofApp.h"

void ofApp::setup() {
	ofSetWindowTitle("ofxGgmlAudio smoke example");
	request.audioPath = "voice/sample.wav";
	status = ofxGgmlAudioUtils::describe(request);
	ofLogNotice("ofxGgmlAudioTranscribeExample") << status;
}

void ofApp::draw() {
	ofBackground(18);
	ofSetColor(240);
	ofDrawBitmapString("ofxGgmlAudio", 32, 48);
	ofDrawBitmapString(status, 32, 78);
}