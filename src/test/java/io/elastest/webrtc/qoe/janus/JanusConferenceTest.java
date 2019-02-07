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
package io.elastest.webrtc.qoe.janus;

import static java.lang.invoke.MethodHandles.lookup;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.slf4j.LoggerFactory.getLogger;

import java.io.File;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.openqa.selenium.By;
import org.openqa.selenium.WebDriver;
import org.openqa.selenium.WebElement;
import org.openqa.selenium.chrome.ChromeDriver;
import org.openqa.selenium.support.ui.ExpectedConditions;
import org.openqa.selenium.support.ui.WebDriverWait;
import org.slf4j.Logger;

import io.elastest.webrtc.qoe.ElasTestRemoteControlParent;
import io.github.bonigarcia.seljup.Arguments;
import io.github.bonigarcia.seljup.SeleniumExtension;

@ExtendWith(SeleniumExtension.class)
public class JanusConferenceTest extends ElasTestRemoteControlParent {

    final Logger log = getLogger(lookup().lookupClass());

    static final String SUT_URL = "https://janus.conf.meetecho.com/videoroomtest.html";
    static final int TEST_TIME_SEC = 5;
    static final String PRESENTER_NAME = "presenter";
    static final String VIEWER_NAME = "viewer";

    ChromeDriver presenter;
    ChromeDriver viewer;

    public JanusConferenceTest(
            @Arguments({ FAKE_DEVICE, FAKE_UI }) ChromeDriver presenter,
            @Arguments({ FAKE_DEVICE, FAKE_UI }) ChromeDriver viewer) {
        super(SUT_URL, presenter, viewer);
        this.presenter = presenter;
        this.viewer = viewer;
    }

    @Test
    void janusTest() throws Exception {
        // Presenter
        startPeer(presenter, PRESENTER_NAME);

        // Viewer
        startPeer(viewer, VIEWER_NAME);

        String pc = "peerConnections[0]";
        waitForJsObject(presenter, pc);
        Object presenterPc = executeScript(presenter, "return " + pc + ";");
        log.info("presenter pc {}", presenterPc);

        waitForJsObject(viewer, pc);
        Object viewerPc = executeScript(viewer, "return " + pc + ";");
        log.info("viewer pc {}", viewerPc);

        // Recording
        int num = 0;
        do {
            num = Integer.parseInt(
                    executeScript(viewer, "return peerConnections.length;")
                            .toString());
            log.info("Number of peerConnections: {}", num);
        } while (num < 2);

        startRecording(presenter, "peerConnections[0].getLocalStreams()[0]");
        startRecording(viewer,
                "peerConnections[" + (num - 1) + "].getRemoteStreams()[0]");

        waitSeconds(TEST_TIME_SEC);
        stopRecording(presenter);
        stopRecording(viewer);

        File presenterRecording = getRecording(presenter);
        assertTrue(presenterRecording.exists());
        File viewerRecording = getRecording(viewer);
        assertTrue(viewerRecording.exists());
    }

    private void startPeer(WebDriver driver, String name) {
        driver.findElement(By.id("start")).click();
        WebDriverWait wait = new WebDriverWait(presenter, 5);
        WebElement username = driver.findElement(By.id("username"));
        wait.until(ExpectedConditions.visibilityOf(username));
        username.sendKeys(name);
        driver.findElement(By.id("register")).click();
    }

}
