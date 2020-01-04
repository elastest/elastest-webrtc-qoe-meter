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
import org.openqa.selenium.WebDriver;
import org.slf4j.Logger;

import io.elastest.webrtc.qoe.ElasTestRemoteControlParent;
import io.github.bonigarcia.seljup.SeleniumExtension;

@ExtendWith(SeleniumExtension.class)
public class GetDateTest extends ElasTestRemoteControlParent {

    final Logger log = getLogger(lookup().lookupClass());

    WebDriver driver1, driver2;

    public GetDateTest(WebDriver driver1, WebDriver driver2) {
        super("https://bonigarcia.github.io/selenium-jupiter/", driver1,
                driver2);
        this.driver1 = driver1;
        this.driver2 = driver2;
    }

    @Test
    void dateTest() {
        String getDate = "var now = new Date();";
        getDate += "var date = now.getFullYear() + '-' + (now.getMonth() + 1) + '-' + now.getDate();";
        getDate += "var time = now.getHours() + ':' + now.getMinutes() + ':' + now.getSeconds() + '.' + now.getMilliseconds();";
        getDate += "return date + ' ' + time;";
        Object date1 = executeScript(driver1, getDate);
        Object date2 = executeScript(driver2, getDate);
        log.debug("Date in browser #1: {}", date1);
        log.debug("Date in browser #2: {}", date2);
        assertThat(date1, notNullValue());
        assertThat(date2, notNullValue());
    }

}
