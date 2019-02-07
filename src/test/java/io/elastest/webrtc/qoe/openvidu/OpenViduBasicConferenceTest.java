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

import static java.lang.invoke.MethodHandles.lookup;
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
public class OpenViduBasicConferenceTest extends ElasTestRemoteControlParent {

    final Logger log = getLogger(lookup().lookupClass());

    static final String SUT_URL = "https://demos.openvidu.io/basic-videoconference/";
    static final int TEST_TIME_SEC = 3;
    static final String PRESENTER_NAME = "presenter";
    static final String VIEWER_NAME = "viewer";
    static final String SESSION_NAME = "qoe-session";

    ChromeDriver presenter;
    ChromeDriver viewer;

    public OpenViduBasicConferenceTest(
            @Arguments({ FAKE_DEVICE, FAKE_UI }) ChromeDriver presenter,
            @Arguments({ FAKE_DEVICE, FAKE_UI }) ChromeDriver viewer) {
        super(SUT_URL, presenter, viewer);
        this.presenter = presenter;
        this.viewer = viewer;
    }

    @Test
    void openviduTest() throws Exception {
        // Presenter
        clearAndSendKeysToElementById(presenter, "userName", PRESENTER_NAME);
        clearAndSendKeysToElementById(presenter, "sessionId", SESSION_NAME);
        presenter.findElement(By.name("commit")).click();

        // Viewer
        clearAndSendKeysToElementById(viewer, "userName", VIEWER_NAME);
        clearAndSendKeysToElementById(viewer, "sessionId", SESSION_NAME);
        viewer.findElement(By.name("commit")).click();

        // Recordings
        startRecording(presenter,
                "session.streamManagers[0].stream.webRtcPeer.pc.getLocalStreams()[0]");
        startRecording(viewer,
                "session.streamManagers[0].stream.webRtcPeer.pc.getRemoteStreams()[0]");

        waitSeconds(TEST_TIME_SEC);
        stopRecording(presenter);
        stopRecording(viewer);

        File presenterRecording = getRecording(presenter);
        assertTrue(presenterRecording.exists());

        File viewerRecording = getRecording(viewer);
        assertTrue(viewerRecording.exists());
    }

}
