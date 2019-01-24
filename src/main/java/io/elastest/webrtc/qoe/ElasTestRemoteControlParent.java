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
import static java.lang.System.nanoTime;
import static java.lang.Thread.sleep;
import static java.lang.invoke.MethodHandles.lookup;
import static java.nio.charset.Charset.defaultCharset;
import static java.nio.file.Files.readAllBytes;
import static org.apache.commons.codec.binary.Base64.decodeBase64;
import static org.apache.commons.io.FileUtils.writeByteArrayToFile;
import static org.apache.commons.io.IOUtils.copy;
import static org.slf4j.LoggerFactory.getLogger;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.StringWriter;
import java.nio.file.NoSuchFileException;
import java.util.Arrays;
import java.util.List;
import java.util.concurrent.TimeUnit;

import org.openqa.selenium.JavascriptExecutor;
import org.openqa.selenium.WebDriver;
import org.slf4j.Logger;

public class ElasTestRemoteControlParent {

    final Logger log = getLogger(lookup().lookupClass());

    static final String REMOTE_CONTROL_JS_OBJECT = "elasTestRemoteControl";
    static final int POLL_TIME_MS = 500;

    public List<WebDriver> drivers;
    public String sut;

    public ElasTestRemoteControlParent(String sut, WebDriver... drivers) {
        this.drivers = Arrays.asList(drivers);
        this.sut = sut;

        this.drivers.stream().forEach(this::initDriver);
    }

    private void initDriver(WebDriver driver) {
        try {
            log.debug("Testing {} with {}", sut, driver);
            driver.get(sut);

            injectRemoteControlJs(driver);
            injectRecordRtc(driver);
        } catch (Exception e) {
            log.warn("Exception injecting JavaScript files", e);
        }
    }

    private void injectRemoteControlJs(WebDriver driver) throws IOException {
        String jsPath = "js/script.min.js";
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
        recordingJs += "recScript.src='https://cdn.webrtc-experiment.com/RecordRTC.js';";
        recordingJs += "window.document.head.appendChild(recScript);";
        recordingJs += "return true;";
        this.executeScript(driver, recordingJs);

        // Wait for RecordRTC object
        Object recordRTC = null;
        do {

            try {
                recordRTC = this.executeScript(driver, "return RecordRTC");
                log.trace("RecordRTC object already available {}", recordRTC);
            } catch (Exception e) {
                log.trace(
                        "RecordRTC object still not available ... retrying in {} ms",
                        POLL_TIME_MS);
                waitMilliSeconds(POLL_TIME_MS);
            }
        } while (recordRTC == null);
    }

    private Object executeScript(WebDriver driver, String command) {
        return ((JavascriptExecutor) driver).executeScript(command);
    }

    private Object getProperty(WebDriver driver, String property) {
        Object value = null;
        for (int i = 0; i < 60; i++) {
            value = executeScript(driver, "return " + REMOTE_CONTROL_JS_OBJECT
                    + "." + property + ";");
            if (value != null) {
                break;
            } else {
                log.debug("{} not present still... waiting {} ms", property,
                        POLL_TIME_MS);
                waitMilliSeconds(POLL_TIME_MS);
            }
        }
        String clazz = value != null ? value.getClass().getName() : "";
        log.trace(">>> getProperty {} {} {}", property, value, clazz);
        return value;
    }

    // Public API

    public String sayHello(WebDriver driver) {
        return executeScript(driver,
                "return " + REMOTE_CONTROL_JS_OBJECT + ".sayHello();")
                        .toString();
    }

    public void startRecording(WebDriver driver) {
        startRecording(driver, "window.stream");
    }

    public void startRecording(WebDriver driver, String stream) {
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
        waitMilliSeconds(TimeUnit.SECONDS.toMillis(seconds));
    }

    public void waitMilliSeconds(long milliseconds) {
        try {
            sleep(milliseconds);
        } catch (InterruptedException e) {
            log.warn("Exception waiting {} ms", milliseconds, e);
        }
    }

}
