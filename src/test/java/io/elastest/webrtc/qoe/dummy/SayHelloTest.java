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
package io.elastest.webrtc.qoe.dummy;

import static java.lang.invoke.MethodHandles.lookup;
import static org.hamcrest.CoreMatchers.notNullValue;
import static org.hamcrest.MatcherAssert.assertThat;
import static org.slf4j.LoggerFactory.getLogger;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.openqa.selenium.chrome.ChromeDriver;
import org.slf4j.Logger;

import io.elastest.webrtc.qoe.ElasTestRemoteControlParent;
import io.github.bonigarcia.seljup.SeleniumExtension;

@ExtendWith(SeleniumExtension.class)
public class SayHelloTest extends ElasTestRemoteControlParent {

    final Logger log = getLogger(lookup().lookupClass());

    ChromeDriver driver;

    public SayHelloTest(ChromeDriver driver) {
        super("https://bonigarcia.github.io/selenium-jupiter/", driver);
        this.driver = driver;
    }

    @Test
    void helloTest() throws InterruptedException {
        String sayHello = sayHello(driver);
        log.debug("Message from remote control: {}", sayHello);
        assertThat(sayHello, notNullValue());
    }

}
