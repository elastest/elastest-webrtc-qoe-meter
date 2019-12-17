/*
 * (C) Copyright 2017-2019 ElasTest (http://elastest.io/)
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */
package io.elastest.webrtc.qoe.openvidu;

import static io.github.bonigarcia.seljup.BrowserType.CHROME;
import static java.lang.Integer.parseInt;
import static java.lang.invoke.MethodHandles.lookup;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.slf4j.LoggerFactory.getLogger;

import java.io.File;

import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.RegisterExtension;
import org.openqa.selenium.By;
import org.openqa.selenium.WebDriver;
import org.openqa.selenium.chrome.ChromeDriver;
import org.slf4j.Logger;

import io.elastest.webrtc.qoe.ElasTestRemoteControlParent;
import io.github.bonigarcia.seljup.Arguments;
import io.github.bonigarcia.seljup.DockerBrowser;
import io.github.bonigarcia.seljup.SeleniumExtension;

public class OpenViduBasicConferenceAudioVideoTest
        extends ElasTestRemoteControlParent {

    @RegisterExtension
    static SeleniumExtension seleniumExtension = new SeleniumExtension();

    final Logger log = getLogger(lookup().lookupClass());

    static final int TEST_TIME_SEC = 35;

    static final String FAKE_VIDEO = "--use-file-for-fake-video-capture=/home/selenium/test.y4m";
    static final String FAKE_AUDIO = "--use-file-for-fake-audio-capture=/home/selenium/test.wav";
    static final String SUT_URL = "https://demos.openvidu.io/basic-videoconference/";
    static final String PRESENTER_NAME = "presenter";
    static final String VIEWER_NAME = "viewer";
    static final String SESSION_NAME = "qoe-session";
    static final String WEBM_EXT = ".webm";

    // The following values are valid: loss, delay, jitter
    static final String TC_TYPE = System.getProperty("tc.type", "");
    static final int TC_VALUE = parseInt(System.getProperty("tc.value", "0"));

    WebDriver presenter, viewer;
    String path = "";

    public OpenViduBasicConferenceAudioVideoTest(@Arguments({ FAKE_DEVICE,
            FAKE_UI, FAKE_VIDEO, FAKE_AUDIO,
            IGNORE_CERTIFICATE }) @DockerBrowser(type = CHROME, version = "beta", volumes = {
                    "~:/home/selenium" }) WebDriver presenter,
            @Arguments({ FAKE_DEVICE, FAKE_UI,
                    IGNORE_CERTIFICATE }) ChromeDriver viewer) {
        super(SUT_URL, presenter, viewer);
        this.presenter = presenter;
        this.viewer = viewer;
    }

    @BeforeAll
    static void setupAll() {
        seleniumExtension.getConfig().setBrowserSessionTimeoutDuration("5m0s");
    }

    @Test
    void openviduTest() throws Exception {
        // Presenter
        log.debug("Presenter in {}", presenter);
        clearAndSendKeysToElementById(presenter, "userName", PRESENTER_NAME);
        clearAndSendKeysToElementById(presenter, "sessionId", SESSION_NAME);
        presenter.findElement(By.name("commit")).click();

        // Wait for session to be registered
        Thread.sleep(2000);

        // Viewer
        log.debug("Viewer in {}", viewer);
        clearAndSendKeysToElementById(viewer, "userName", VIEWER_NAME);
        clearAndSendKeysToElementById(viewer, "sessionId", SESSION_NAME);
        viewer.findElement(By.name("commit")).click();

        // Start recordings
        startRecording(presenter,
                "session.streamManagers[0].stream.webRtcPeer.pc.getLocalStreams()[0]");
        startRecording(viewer,
                "session.streamManagers[0].stream.webRtcPeer.pc.getRemoteStreams()[0]");

        if (TC_VALUE > 0) {
            // Simulate packet loss or delay or jitter in viewer container
            simulateNetwork(seleniumExtension, presenter, TC_TYPE, TC_VALUE);
        }

        // Wait
        waitSeconds(TEST_TIME_SEC);

        if (TC_VALUE > 0) {
            // Reset network
            resetNetwork(seleniumExtension, presenter, TC_TYPE);
        }

        // Stop recordings
        stopRecording(presenter);
        stopRecording(viewer);

        String presenterRecordingName = TC_VALUE + TC_TYPE + "-"
                + PRESENTER_NAME + WEBM_EXT;
        File presenterRecording = getRecording(presenter,
                presenterRecordingName);
        assertTrue(presenterRecording.exists());

        String viewerRecordingName = TC_VALUE + TC_TYPE + "-" + VIEWER_NAME
                + WEBM_EXT;
        File viewerRecording = getRecording(viewer, viewerRecordingName);
        assertTrue(viewerRecording.exists());
    }

}
