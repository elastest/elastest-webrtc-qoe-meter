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

import static java.io.File.createTempFile;
import static java.lang.String.valueOf;
import static java.lang.System.currentTimeMillis;
import static java.lang.System.nanoTime;
import static java.lang.Thread.sleep;
import static java.lang.invoke.MethodHandles.lookup;
import static java.nio.charset.Charset.defaultCharset;
import static java.nio.file.Files.readAllBytes;
import static java.util.concurrent.TimeUnit.SECONDS;
import static org.apache.commons.codec.binary.Base64.decodeBase64;
import static org.apache.commons.io.FileUtils.writeByteArrayToFile;
import static org.apache.commons.io.IOUtils.copy;
import static org.slf4j.LoggerFactory.getLogger;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.StringWriter;
import java.nio.file.NoSuchFileException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;

import org.openqa.selenium.By;
import org.openqa.selenium.JavascriptExecutor;
import org.openqa.selenium.WebDriver;
import org.openqa.selenium.WebElement;
import org.slf4j.Logger;

import com.spotify.docker.client.exceptions.DockerException;

import io.github.bonigarcia.seljup.SeleniumExtension;

public class ElasTestRemoteControlParent {

    final Logger log = getLogger(lookup().lookupClass());

    public static final String FAKE_DEVICE = "--use-fake-device-for-media-stream";
    public static final String FAKE_UI = "--use-fake-ui-for-media-stream";
    public static final String FAKE_FILE = "--use-file-for-fake-video-capture=test.y4m";
    public static final String IGNORE_CERTIFICATE = "--ignore-certificate-errors";

    static final String REMOTE_CONTROL_JS_OBJECT = "elasTestRemoteControl";
    static final int POLL_TIME_MS = 500;
    static final int WAIT_SEC = 30;

    public List<WebDriver> drivers;
    public String sut;

    public ElasTestRemoteControlParent(String sut, WebDriver... drivers) {
        this.drivers = new ArrayList<>(Arrays.asList(drivers));
        this.sut = sut;

        this.drivers.stream().forEach(w -> initDriver(w, true));
    }

    public void addExtraDrivers(List<WebDriver> newDrivers, boolean inject) {
        this.drivers.addAll(newDrivers);

        newDrivers.stream().forEach(w -> initDriver(w, inject));
    }

    private void initDriver(WebDriver driver, boolean inject) {
        try {
            log.debug("Testing {} with {}", sut, driver);
            driver.get(sut);

            if (inject) {
                injectRemoteControlJs(driver);
                injectRecordRtc(driver);
            }
        } catch (Exception e) {
            log.warn("Exception injecting JavaScript files", e);
        }
    }

    private void injectRemoteControlJs(WebDriver driver) throws IOException {
        String jsPath = "js/elastest-remote-control.min.js";
        // The automated minified version would be:
        // String jsPath = "js/script.min.js";

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
        jsContent = jsContent.replaceAll("\r", "").replaceAll("\n", "");
        log.trace("Content of injected file: {}", jsContent);

        String remoteControlJs = "var remoteControlScript=window.document.createElement('script');";
        remoteControlJs += "remoteControlScript.type='text/javascript';";
        remoteControlJs += "remoteControlScript.text='" + jsContent + "';";
        remoteControlJs += "window.document.head.appendChild(remoteControlScript);";
        remoteControlJs += "return true;";
        this.executeScript(driver, remoteControlJs);
    }

    private void injectRecordRtc(WebDriver driver) {
        String recordingJs = "var recScript=window.document.createElement('script');";
        recordingJs += "recScript.type='text/javascript';";
        recordingJs += "recScript.src='https://cdnjs.cloudflare.com/ajax/libs/RecordRTC/5.5.4/RecordRTC.min.js';";
        recordingJs += "window.document.head.appendChild(recScript);";
        recordingJs += "return true;";
        this.executeScript(driver, recordingJs);

        // Wait for RecordRTC object
        waitForJsObject(driver, "RecordRTC");
    }

    private Object getProperty(WebDriver driver, String property) {
        Object value = null;
        for (int i = 0; i < 60; i++) {
            value = executeScript(driver, "return " + REMOTE_CONTROL_JS_OBJECT
                    + "." + property + ";");
            if (value != null) {
                break;
            } else {
                log.debug("{} still not present... waiting {} ms", property,
                        POLL_TIME_MS);
                waitMilliSeconds(POLL_TIME_MS);
            }
        }
        String clazz = value != null ? value.getClass().getName() : "";
        log.trace(">>> getProperty {} {} {}", property, value, clazz);
        return value;
    }

    // Public API

    public Object executeScript(WebDriver driver, String command) {
        return ((JavascriptExecutor) driver).executeScript(command);
    }

    public String sayHello(WebDriver driver) {
        return executeScript(driver,
                "return " + REMOTE_CONTROL_JS_OBJECT + ".sayHello();")
                        .toString();
    }

    public void startRecording(WebDriver driver) {
        startRecording(driver, "window.stream");
    }

    public void startRecording(WebDriver driver, String stream) {
        waitForJsObject(driver, stream);
        executeScript(driver,
                REMOTE_CONTROL_JS_OBJECT + ".startRecording(" + stream + ");");
    }

    public void stopRecording(WebDriver driver) {
        executeScript(driver, REMOTE_CONTROL_JS_OBJECT + ".stopRecording();");
        getProperty(driver, "recordRTC");
    }

    public File saveRecordingToDisk(WebDriver driver, String fileName,
            String downloadsFolder) {
        executeScript(driver, REMOTE_CONTROL_JS_OBJECT
                + ".saveRecordingToDisk('" + fileName + "');");
        File output = new File(downloadsFolder, fileName);
        do {
            if (!output.exists()) {
                waitMilliSeconds(POLL_TIME_MS);
            } else {
                break;
            }
        } while (true);
        return output;
    }

    public void openRecordingInNewTab(WebDriver driver) {
        executeScript(driver,
                REMOTE_CONTROL_JS_OBJECT + ".openRecordingInNewTab();");
    }

    public File getRecording(WebDriver driver) throws IOException {
        File tmpFile = createTempFile(valueOf(nanoTime()), ".webm");
        return getRecording(driver, tmpFile.getAbsolutePath());
    }

    public File getRecording(WebDriver driver, String fileName)
            throws IOException {
        executeScript(driver, REMOTE_CONTROL_JS_OBJECT + ".recordingToData();");
        String recording = getProperty(driver, "recordingData").toString();

        // Base64 to File
        File outputFile = new File(fileName);
        byte[] bytes = decodeBase64(
                recording.substring(recording.lastIndexOf(",") + 1));
        writeByteArrayToFile(outputFile, bytes);

        return outputFile;
    }

    public void waitSeconds(int seconds) {
        waitMilliSeconds(SECONDS.toMillis(seconds));
    }

    public void waitMilliSeconds(long milliseconds) {
        try {
            sleep(milliseconds);
        } catch (InterruptedException e) {
            log.warn("Exception waiting {} ms", milliseconds, e);
        }
    }

    public void waitForJsObject(WebDriver driver, String jsObject) {
        Object object = null;
        long timeoutMs = currentTimeMillis() + SECONDS.toMillis(WAIT_SEC);
        log.debug("Waiting for {} in {} (timeout {} seconds)", jsObject, driver,
                WAIT_SEC);
        do {
            try {
                if (currentTimeMillis() > timeoutMs) {
                    log.warn(
                            "Timeout of {} seconds waiting for object {} ... exiting",
                            WAIT_SEC, jsObject);
                    break;
                }
                object = this.executeScript(driver, "return " + jsObject);
                if (object != null) {
                    log.debug("{} object already available {}", jsObject,
                            object);
                } else {
                    poll(jsObject);
                }
            } catch (Exception e) {
                poll(jsObject);
            }
        } while (object == null);
    }

    private void poll(String jsObject) {
        log.trace("{} object still not available ... retrying in {} ms",
                jsObject, POLL_TIME_MS);
        waitMilliSeconds(POLL_TIME_MS);
    }

    public void clearAndSendKeysToElementById(WebDriver driver, String id,
            String keys) {
        WebElement userName = driver.findElement(By.id(id));
        userName.clear();
        userName.sendKeys(keys);
    }

    public void execCommandInContainer(SeleniumExtension seleniumExtension,
            WebDriver driver, String[] command)
            throws DockerException, InterruptedException {
        Optional<String> containerId = seleniumExtension.getContainerId(driver);
        if (containerId.isPresent()) {
            String container = containerId.get();
            log.debug("Running {} in container {}", Arrays.toString(command),
                    container);

            String result = seleniumExtension.getDockerService()
                    .execCommandInContainer(container, command);
            if (result != null) {
                log.debug("Result: {}", result);
            }
        } else {
            log.warn("Container not present in {}", driver);
        }
    }

    // Simulate network conditions using NetEm
    public void simulateNetwork(SeleniumExtension seleniumExtension,
            WebDriver driver, String tcType, int tcValue)
            throws DockerException, InterruptedException {
        String[] tcCommand;

        switch (tcType.toLowerCase()) {
        case "delay":
            tcCommand = new String[] { "sudo", "tc", "qdisc", "add", "dev",
                    "eth0", "root", "netem", "delay", tcValue + "ms" };
            break;
        case "jitter":
            tcCommand = new String[] { "sudo", "tc", "qdisc", "add", "dev",
                    "eth0", "root", "netem", "delay", tcValue + "ms",
                    tcValue + "ms", "distribution", "normal" };
            break;
        case "loss":
        default:
            tcCommand = new String[] { "sudo", "tc", "qdisc", "add", "dev",
                    "eth0", "root", "netem", "loss", tcValue + "%" };
            break;
        }

        execCommandInContainer(seleniumExtension, driver, tcCommand);
    }

    // Reset network using NetEm
    public void resetNetwork(SeleniumExtension seleniumExtension,
            WebDriver driver, String tcType)
            throws DockerException, InterruptedException {
        String[] tcCommand;

        switch (tcType.toLowerCase()) {
        case "delay":
        case "jitter":
            tcCommand = new String[] { "sudo", "tc", "qdisc", "replace", "dev",
                    "eth0", "root", "netem", "delay", "0ms", "0ms" };
            break;
        case "loss":
        default:
            tcCommand = new String[] { "sudo", "tc", "qdisc", "replace", "dev",
                    "eth0", "root", "netem", "loss", "0%" };
            break;
        }

        execCommandInContainer(seleniumExtension, driver, tcCommand);
    }

}
