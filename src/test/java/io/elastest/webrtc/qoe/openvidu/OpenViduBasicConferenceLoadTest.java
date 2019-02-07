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
import static java.lang.invoke.MethodHandles.lookup;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.slf4j.LoggerFactory.getLogger;

import java.io.File;
import java.util.List;

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

public class OpenViduBasicConferenceLoadTest
        extends ElasTestRemoteControlParent {

    @RegisterExtension
    static SeleniumExtension seleniumExtension = new SeleniumExtension();

    final Logger log = getLogger(lookup().lookupClass());

    static final String SUT_URL = "https://demos.openvidu.io/basic-videoconference/";
    static final int TEST_TIME_SEC = 15;
    static final int NUM_VIEWERS = 5;
    static final String PRESENTER_NAME = "presenter";
    static final String VIEWER_NAME = "viewer";
    static final String SESSION_NAME = "qoe-session";
    static final String WEBM_EXT = ".webm";

    ChromeDriver presenter, viewer;
    List<WebDriver> viewers;

    public OpenViduBasicConferenceLoadTest(
            @Arguments({ FAKE_DEVICE, FAKE_UI,
                    FAKE_FILE }) ChromeDriver presenter,
            @Arguments({ FAKE_DEVICE, FAKE_UI }) ChromeDriver viewer,
            @Arguments({ FAKE_DEVICE,
                    FAKE_UI }) @DockerBrowser(type = CHROME, size = NUM_VIEWERS) List<WebDriver> viewers) {
        super(SUT_URL, presenter, viewer);
        addExtraDrivers(viewers);

        this.presenter = presenter;
        this.viewer = viewer;
        this.viewers = viewers;
    }

    @BeforeAll
    static void setup() {
        seleniumExtension.getConfig().setAndroidDeviceTimeoutSec(40);
    }

    @Test
    void openviduLoadTest() throws Exception {
        // Presenter
        addUserToSession(presenter, SESSION_NAME, PRESENTER_NAME);

        // Viewers
        addUserToSession(viewer, SESSION_NAME, VIEWER_NAME);
        for (int i = 0; i < viewers.size(); i++) {
            addUserToSession(viewers.get(i), SESSION_NAME,
                    VIEWER_NAME + "-docker" + (i + 1));
        }

        // Start recordings
        startRecording(presenter,
                "session.streamManagers[0].stream.webRtcPeer.pc.getLocalStreams()[0]");
        startRecording(viewer,
                "session.streamManagers[0].stream.webRtcPeer.pc.getRemoteStreams()[0]");

        // Wait session time
        waitSeconds(TEST_TIME_SEC);

        // Stop recordings
        stopRecording(presenter);
        stopRecording(viewer);

        // Get recordings
        File presenterRecording = getRecording(presenter,
                PRESENTER_NAME + WEBM_EXT);
        File viewerRecording = getRecording(viewer, VIEWER_NAME + WEBM_EXT);

        // Assert recordings
        assertTrue(presenterRecording.exists());
        assertTrue(viewerRecording.exists());
    }

    private void addUserToSession(WebDriver driver, String sessionId,
            String userName) {
        clearAndSendKeysToElementById(driver, "userName", userName);
        clearAndSendKeysToElementById(driver, "sessionId", sessionId);
        driver.findElement(By.name("commit")).click();
    }

}
