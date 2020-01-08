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

import static java.lang.invoke.MethodHandles.lookup;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.slf4j.LoggerFactory.getLogger;

import java.io.File;
import java.io.IOException;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.openqa.selenium.By;
import org.openqa.selenium.chrome.ChromeDriver;
import org.openqa.selenium.support.ui.Select;
import org.slf4j.Logger;

import io.elastest.webrtc.qoe.ElasTestRemoteControlParent;
import io.github.bonigarcia.seljup.Arguments;
import io.github.bonigarcia.seljup.SeleniumExtension;

@ExtendWith(SeleniumExtension.class)
public class WebRtcSamplesPeerconnectionBandwidthLocalTest
        extends ElasTestRemoteControlParent {

    final Logger log = getLogger(lookup().lookupClass());

    static final String SUT_URL = "https://webrtc.github.io/samples/src/content/peerconnection/bandwidth/";
    static final String FAKE_DEVICE = "--use-fake-device-for-media-stream=fps=60";

    static final int TEST_TIME_SEC = 35;

    ChromeDriver driver;

    public WebRtcSamplesPeerconnectionBandwidthLocalTest(
            @Arguments({ DISABLE_SMOOTHNESS, FAKE_DEVICE, FAKE_UI, FAKE_VIDEO,
                    FAKE_AUDIO }) ChromeDriver driver) {
        super(SUT_URL, driver);
        this.driver = driver;
        forceGetUserMediaVideoAndAudio(driver);
    }

    @Test
    void webrtcTest() throws IOException {
        driver.findElement(By.id("callButton")).click();

        // Set bandwidth to 2000bps
        waitSeconds(1);
        Select bandwidth = new Select(driver.findElement(By.id("bandwidth")));
        bandwidth.selectByVisibleText("2000");

        // Star recording in viewer
        startRecording(driver, "pc2.getRemoteStreams()[0]");

        waitSeconds(TEST_TIME_SEC);
        stopRecording(driver);

        String viewerRecordingName = "viewer.webm";
        File recording = getRecording(driver, viewerRecordingName);
        assertTrue(recording.exists());

        driver.findElement(By.id("hangupButton")).click();
    }

}
