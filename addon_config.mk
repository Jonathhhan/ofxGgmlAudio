meta:
	ADDON_NAME = ofxGgmlAudio
	ADDON_DESCRIPTION = Companion addon for local audio inference, speech recognition, and voice workflows on top of ofxGgmlCore
	ADDON_AUTHOR = Jonathan Frank
	ADDON_TAGS = "ggml,ai,audio,speech,whisper,transcription,denoising,voice"
	ADDON_URL = https://github.com/Jonathhhan/ofxGgmlAudio

common:
	ADDON_DEPENDENCIES += ofxGgmlCore
	ADDON_INCLUDES += src
	ADDON_INCLUDES += libs/whisper/include
	# Native whisper.cpp bridge is opt-in after scripts/build-whisper.*:
	# ADDON_CFLAGS += -DOFXGGMLAUDIO_WITH_WHISPER
	ADDON_SOURCES_EXCLUDE += build/%
	ADDON_SOURCES_EXCLUDE += libs/whisper/.source/%
	ADDON_SOURCES_EXCLUDE += libs/whisper/build/%
	ADDON_SOURCES_EXCLUDE += libs/whisper/build*/%
	ADDON_SOURCES_EXCLUDE += libs/*/build/%
	ADDON_SOURCES_EXCLUDE += libs/*/build*/%
	ADDON_INCLUDES_EXCLUDE += build/%
	ADDON_INCLUDES_EXCLUDE += libs/whisper/.source/%
	ADDON_INCLUDES_EXCLUDE += libs/whisper/build/%
	ADDON_INCLUDES_EXCLUDE += libs/whisper/build*/%
	ADDON_INCLUDES_EXCLUDE += libs/*/build/%
	ADDON_INCLUDES_EXCLUDE += libs/*/build*/%

vs:
	# Enable with OFXGGMLAUDIO_WITH_WHISPER after local runtime setup:
	# ADDON_LIBS += libs/whisper/lib/whisper.lib

linux64:
	# Enable with OFXGGMLAUDIO_WITH_WHISPER after local runtime setup:
	# ADDON_LIBS += libs/whisper/lib/libwhisper.a

osx:
	# Enable with OFXGGMLAUDIO_WITH_WHISPER after local runtime setup:
	# ADDON_LIBS += libs/whisper/lib/libwhisper.a
