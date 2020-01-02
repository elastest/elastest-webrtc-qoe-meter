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
import static org.hamcrest.CoreMatchers.equalTo;
import static org.hamcrest.MatcherAssert.assertThat;
import static org.slf4j.LoggerFactory.getLogger;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.openqa.selenium.By;
import org.openqa.selenium.chrome.ChromeDriver;
import org.openqa.selenium.chrome.ChromeOptions;
import org.slf4j.Logger;

import io.github.bonigarcia.seljup.Options;
import io.github.bonigarcia.seljup.SeleniumExtension;

@ExtendWith(SeleniumExtension.class)
public class WebRtcSamplesTest {

    final Logger log = getLogger(lookup().lookupClass());

    @Options
    ChromeOptions chromeOptions = new ChromeOptions();
    {
        chromeOptions.addArguments("--use-fake-device-for-media-stream",
                "--use-fake-ui-for-media-stream");
    }

    @Test
    void webrtcTest(ChromeDriver driver) {
        String sut = "https://webrtc.github.io/samples/src/content/devices/input-output/";
        log.debug("Testing {} with {}", sut, driver);
        driver.get(sut);
        assertThat(driver.findElement(By.id("video")).getTagName(),
                equalTo("video"));
    }

}
