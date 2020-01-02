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
import org.slf4j.Logger;

import io.elastest.webrtc.qoe.ElasTestRemoteControlParent;
import io.github.bonigarcia.seljup.Arguments;
import io.github.bonigarcia.seljup.SeleniumExtension;

@ExtendWith(SeleniumExtension.class)
public class RecordWebRtcSamples3Test extends ElasTestRemoteControlParent {

    final Logger log = getLogger(lookup().lookupClass());

    static final String SUT_URL = "http://localhost:8080/src/content/peerconnection/bandwidth/";
    static final String DISABLE_SMOOTHNESS = "--disable-rtc-smoothness-algorithm";
    static final String FAKE_DEVICE = "--use-fake-device-for-media-stream=fps=60";
    static final String FAKE_UI = "--use-fake-ui-for-media-stream";
    static final String FAKE_VIDEO = "--use-file-for-fake-video-capture=test.y4m";
    static final String FAKE_AUDIO = "--use-file-for-fake-audio-capture=test.wav";
    static final int TEST_TIME_SEC = 10;

    ChromeDriver driver;

    public RecordWebRtcSamples3Test(
            @Arguments({ DISABLE_SMOOTHNESS, FAKE_DEVICE, FAKE_UI, FAKE_VIDEO,
                    FAKE_AUDIO }) ChromeDriver driver) {
        super(SUT_URL, driver);
        this.driver = driver;
    }

    @Test
    void webrtcTest() throws IOException {
        driver.findElement(By.id("callButton")).click();

        // For recording sender
        // startRecording(driver, "pc1.getLocalStreams()[0]");

        // For recording receiver
        startRecording(driver, "pc2.getRemoteStreams()[0]");

        waitSeconds(TEST_TIME_SEC);
        stopRecording(driver);

        File recording = getRecording(driver);
        assertTrue(recording.exists());

        driver.findElement(By.id("hangupButton")).click();
    }

}
