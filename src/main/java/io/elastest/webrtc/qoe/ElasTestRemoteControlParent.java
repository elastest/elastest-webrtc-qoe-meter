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
package io.elastest.webrtc.qoe;

import static java.lang.invoke.MethodHandles.lookup;
import static java.nio.charset.Charset.defaultCharset;
import static java.nio.file.Files.readAllBytes;
import static org.apache.commons.io.IOUtils.copy;
import static org.slf4j.LoggerFactory.getLogger;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.StringWriter;
import java.nio.file.NoSuchFileException;

import org.openqa.selenium.JavascriptExecutor;
import org.openqa.selenium.WebDriver;
import org.slf4j.Logger;

public class ElasTestRemoteControlParent {

    final Logger log = getLogger(lookup().lookupClass());

    static final String REMOTE_CONTROL_JS_OBJECT = "elasTestRemoteControl";

    public WebDriver driver;
    public String sut;

    public ElasTestRemoteControlParent(WebDriver driver, String sut) {
        this.driver = driver;
        this.sut = sut;

        initDriver();
    }

    private void initDriver() {
        try {
            String sut = "https://bonigarcia.github.io/selenium-jupiter/";
            log.debug("Testing {} with {}", sut, driver);
            driver.get(sut);

            injectRemoteControlJs();
        } catch (IOException e) {
            log.warn("Exception injecting remote-control JavaScript", e);
        }
    }

    private void injectRemoteControlJs() throws IOException {
        String jsPath = "elastest-remote-control.min.js";
        log.debug("Injecting {} in {}", jsPath, driver);

        String jsContent = "";
        try {
            File pageFile = new File(this.getClass().getClassLoader()
                    .getResource(jsPath).getFile());
            jsContent = new String(readAllBytes(pageFile.toPath()));
        } catch (NoSuchFileException nsfe) {
            InputStream inputStream = this.getClass().getClassLoader()
                    .getResourceAsStream(jsPath);
            StringWriter writer = new StringWriter();
            copy(inputStream, writer, defaultCharset());
            jsContent = writer.toString();
        }
        log.debug("Content of injected file: {}", jsContent);

        String remoteControlJs = "var remoteControlScript=window.document.createElement('script');";
        remoteControlJs += "remoteControlScript.type='text/javascript';";
        remoteControlJs += "remoteControlScript.text='" + jsContent + "';";
        remoteControlJs += "window.document.head.appendChild(remoteControlScript);";
        remoteControlJs += "return true;";
        this.executeScript(remoteControlJs);
    }

    private Object executeScript(String command) {
        return ((JavascriptExecutor) driver).executeScript(command);
    }

    public String sayHello() {
        return executeScript(
                "return " + REMOTE_CONTROL_JS_OBJECT + ".sayHello();")
                        .toString();
    }

}
