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

import static java.lang.invoke.MethodHandles.lookup;
import static java.util.UUID.randomUUID;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.slf4j.LoggerFactory.getLogger;

import java.io.File;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.openqa.selenium.By;
import org.openqa.selenium.chrome.ChromeDriver;
import org.slf4j.Logger;

import io.elastest.webrtc.qoe.ElasTestRemoteControlParent;
import io.github.bonigarcia.seljup.Arguments;
import io.github.bonigarcia.seljup.SeleniumExtension;

@ExtendWith(SeleniumExtension.class)
public class AppRtcBasicTest extends ElasTestRemoteControlParent {

    final Logger log = getLogger(lookup().lookupClass());

    static final String SUT_URL = "https://appr.tc/";
    static final int TEST_TIME_SEC = 10;
    static final String SESSION_NAME = randomUUID().toString();

    ChromeDriver presenter;
    ChromeDriver viewer;

    public AppRtcBasicTest(
            @Arguments({ FAKE_DEVICE, FAKE_UI }) ChromeDriver presenter,
            @Arguments({ FAKE_DEVICE, FAKE_UI }) ChromeDriver viewer) {
        super(SUT_URL, presenter, viewer);
        this.presenter = presenter;
        this.viewer = viewer;
    }

    @Test
    void appRtcTest() throws Exception {
        // Presenter
        clearAndSendKeysToElementById(presenter, "room-id-input", SESSION_NAME);
        presenter.findElement(By.id("join-button")).click();

        // Viewer
        clearAndSendKeysToElementById(viewer, "room-id-input", SESSION_NAME);
        viewer.findElement(By.id("join-button")).click();

        // Recordings
        startRecording(presenter, "peerConnections[0].getLocalStreams()[0]");
        startRecording(viewer, "peerConnections[0].getRemoteStreams()[0]");

        // Call time
        log.debug("WebRTC call ({} seconds)", TEST_TIME_SEC);
        waitSeconds(TEST_TIME_SEC);

        // Stop and get recordings
        stopRecording(presenter);
        stopRecording(viewer);

        String presenterRecordingName = "presenter.webm";
        File recordingPresenter = getRecording(viewer, presenterRecordingName);
        assertTrue(recordingPresenter.exists());

        String viewerRecordingName = "viewer.webm";
        File recordingViewer = getRecording(viewer, viewerRecordingName);
        assertTrue(recordingViewer.exists());
    }

}
