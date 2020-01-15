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
package io.elastest.webrtc.qoe.webrtcsamples;

import static io.github.bonigarcia.seljup.BrowserType.CHROME;
import static java.lang.Float.parseFloat;
import static java.lang.invoke.MethodHandles.lookup;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.slf4j.LoggerFactory.getLogger;

import java.io.File;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.RegisterExtension;
import org.openqa.selenium.By;
import org.openqa.selenium.WebDriver;
import org.slf4j.Logger;

import io.elastest.webrtc.qoe.ElasTestRemoteControlParent;
import io.github.bonigarcia.seljup.Arguments;
import io.github.bonigarcia.seljup.DockerBrowser;
import io.github.bonigarcia.seljup.SeleniumExtension;

public class WebRtcSamplesPeerconnectionBandwidthDockerTest
        extends ElasTestRemoteControlParent {

    @RegisterExtension
    static SeleniumExtension seleniumExtension = new SeleniumExtension();

    final Logger log = getLogger(lookup().lookupClass());

    static final String SUT_URL = "https://webrtc.github.io/samples/src/content/peerconnection/bandwidth/";
    static final String FAKE_DEVICE = "--use-fake-device-for-media-stream";
    static final String FAKE_UI = "--use-fake-ui-for-media-stream";
    static final String FAKE_VIDEO = "--use-file-for-fake-video-capture=/home/selenium/test.y4m";
    static final String FAKE_AUDIO = "--use-file-for-fake-audio-capture=/home/selenium/test.wav";
    static final String IFACE = "lo";

    static final int TEST_TIME_SEC = 35;

    // The following values are valid: loss, delay, jitter
    static final String TC_TYPE = System.getProperty("tc.type", "loss");
    static final float TC_VALUE = parseFloat(
            System.getProperty("tc.value", "22.5"));

    WebDriver driver;

    public WebRtcSamplesPeerconnectionBandwidthDockerTest(@Arguments({
            FAKE_DEVICE, FAKE_UI, FAKE_VIDEO,
            FAKE_AUDIO }) @DockerBrowser(type = CHROME, version = "beta", volumes = {
                    ".:/home/selenium" }) WebDriver driver) {
        super(SUT_URL, driver);
        this.driver = driver;
        forceGetUserMediaVideoAndAudio(driver);
    }

    @Test
    void webrtcTest() throws Exception {
        // Star call
        driver.findElement(By.id("callButton")).click();

        // Star recording in viewer
        startRecording(driver, "pc2.getRemoteStreams()[0]");

        // Simulate packet loss or delay or jitter in viewer container
        if (TC_VALUE > 0) {
            simulateNetwork(seleniumExtension, driver, IFACE, TC_TYPE,
                    TC_VALUE);
        }

        // Call time
        log.debug("WebRTC call ({} seconds)", TEST_TIME_SEC);
        waitSeconds(TEST_TIME_SEC);

        // Reset network
        if (TC_VALUE > 0) {
            resetNetwork(seleniumExtension, driver, IFACE, TC_TYPE);
        }

        // Stop recording
        stopRecording(driver);

        // Get recording
        String viewerRecordingName = TC_VALUE + TC_TYPE + "-viewer.webm";
        File viewerRecording = getRecording(driver, viewerRecordingName);
        assertTrue(viewerRecording.exists());

        // Stop call
        driver.findElement(By.id("hangupButton")).click();
    }

}
