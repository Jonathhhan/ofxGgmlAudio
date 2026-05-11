#pragma once

#include "ofMain.h"
#include "ofxGgmlSpeech.h"

class ofApp : public ofBaseApp {
public:
	void setup() override;
	void draw() override;

private:
	ofxGgmlSpeechRequest request;
	std::string status;
};