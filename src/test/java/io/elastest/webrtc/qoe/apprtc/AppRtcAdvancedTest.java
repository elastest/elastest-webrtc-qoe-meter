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
package io.elastest.webrtc.qoe.apprtc;

import static io.github.bonigarcia.seljup.BrowserType.CHROME;
import static java.lang.Integer.parseInt;
import static java.lang.invoke.MethodHandles.lookup;
import static java.util.UUID.randomUUID;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.slf4j.LoggerFactory.getLogger;

import java.io.File;

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

public class AppRtcAdvancedTest extends ElasTestRemoteControlParent {

    @RegisterExtension
    static SeleniumExtension seleniumExtension = new SeleniumExtension();

    final Logger log = getLogger(lookup().lookupClass());

    static final String FAKE_VIDEO = "--use-file-for-fake-video-capture=/home/selenium/test.y4m";
    static final String FAKE_AUDIO = "--use-file-for-fake-audio-capture=/home/selenium/test.wav";
    static final String SUT_URL = "https://appr.tc/?stereo=true&audio=echoCancellation=false";
    static final String PRESENTER_NAME = "presenter";
    static final String VIEWER_NAME = "viewer";
    static final String SESSION_NAME = randomUUID().toString();
    static final String WEBM_EXT = ".webm";
    static final String IFACE = "eth0";
    static final int TEST_TIME_SEC = 35;

    // The following values are valid: loss, delay, jitter
    static final String TC_TYPE = System.getProperty("tc.type", "");
    static final int TC_VALUE = parseInt(System.getProperty("tc.value", "0"));

    WebDriver presenter, viewer;

    public AppRtcAdvancedTest(@Arguments({ FAKE_DEVICE, FAKE_UI, FAKE_VIDEO,
            FAKE_AUDIO }) @DockerBrowser(type = CHROME, version = "beta", volumes = {
                    ".:/home/selenium" }) WebDriver presenter,
            @Arguments({ FAKE_DEVICE, FAKE_UI }) ChromeDriver viewer) {
        super(SUT_URL, presenter, viewer);
        this.presenter = presenter;
        this.viewer = viewer;
    }

    @Test
    void appRtcTest() throws Exception {
        // Start presenter
        clearAndSendKeysToElementById(presenter, "room-id-input", SESSION_NAME);
        presenter.findElement(By.id("join-button")).click();

        // Start viewer
        clearAndSendKeysToElementById(viewer, "room-id-input", SESSION_NAME);
        viewer.findElement(By.id("join-button")).click();

        // Start recording in viewer
        startRecording(viewer, "peerConnections[0].getRemoteStreams()[0]");

        // Simulate packet loss delay or jitter in presenter container
        if (TC_VALUE > 0) {
            simulateNetwork(seleniumExtension, presenter, IFACE, TC_TYPE,
                    TC_VALUE);
        }

        // Call
        log.debug("WebRTC call ({} seconds)", TEST_TIME_SEC);
        waitSeconds(TEST_TIME_SEC);

        // Reset network
        if (TC_VALUE > 0) {
            resetNetwork(seleniumExtension, presenter, IFACE, TC_TYPE);
        }

        // Stop recording
        stopRecording(viewer);
        String viewerRecordingName = TC_VALUE + TC_TYPE + "-" + VIEWER_NAME
                + WEBM_EXT;
        File viewerRecording = getRecording(viewer, viewerRecordingName);
        assertTrue(viewerRecording.exists());
    }

}
