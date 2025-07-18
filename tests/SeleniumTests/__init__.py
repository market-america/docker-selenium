import concurrent.futures
import os
import random
import time
import traceback
import unittest

from selenium import webdriver
from selenium.webdriver.chrome.options import Options as ChromeOptions
from selenium.webdriver.common.by import By
from selenium.webdriver.edge.options import Options as EdgeOptions
from selenium.webdriver.firefox.options import Options as FirefoxOptions
from selenium.webdriver.remote.client_config import ClientConfig
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait

SELENIUM_GRID_PROTOCOL = os.environ.get('SELENIUM_GRID_PROTOCOL', 'http')
SELENIUM_GRID_HOST = os.environ.get('SELENIUM_GRID_HOST', 'localhost')
SELENIUM_GRID_PORT = os.environ.get('SELENIUM_GRID_PORT', '4444')
SELENIUM_GRID_USERNAME = os.environ.get('SELENIUM_GRID_USERNAME', None)
SELENIUM_GRID_PASSWORD = os.environ.get('SELENIUM_GRID_PASSWORD', None)
CHART_CERT_PATH = os.environ.get('CHART_CERT_PATH', None)
SELENIUM_GRID_TEST_HEADLESS = os.environ.get('SELENIUM_GRID_TEST_HEADLESS', 'false').lower() == 'true'
SELENIUM_ENABLE_MANAGED_DOWNLOADS = os.environ.get('SELENIUM_ENABLE_MANAGED_DOWNLOADS', 'true').lower() == 'true'
WEB_DRIVER_WAIT_TIMEOUT = int(os.environ.get('WEB_DRIVER_WAIT_TIMEOUT', 60))
TEST_PARALLEL_HARDENING = os.environ.get('TEST_PARALLEL_HARDENING', 'false').lower() == 'true'
TEST_PARALLEL_COUNT = int(os.environ.get('TEST_PARALLEL_COUNT', 5))
TEST_DELAY_AFTER_TEST = int(os.environ.get('TEST_DELAY_AFTER_TEST', 0))
TEST_NODE_RELAY = os.environ.get('TEST_NODE_RELAY', 'false')
TEST_ANDROID_PLATFORM_API = os.environ.get('ANDROID_PLATFORM_API')
TEST_PLATFORMS = os.environ.get('TEST_PLATFORMS', 'linux/amd64')
TEST_FIREFOX_INSTALL_LANG_PACKAGE = os.environ.get('TEST_FIREFOX_INSTALL_LANG_PACKAGE', 'false').lower() == 'true'
TEST_ADD_CAPS_RECORD_VIDEO = os.environ.get('TEST_ADD_CAPS_RECORD_VIDEO', 'true').lower() == 'true'
TEST_CUSTOM_SPECIFIC_NAME = os.environ.get('TEST_CUSTOM_SPECIFIC_NAME', 'false').lower() == 'true'
TEST_MULTIPLE_VERSIONS = os.environ.get('TEST_MULTIPLE_VERSIONS', 'false').lower() == 'true'
TEST_MULTIPLE_PLATFORMS = os.environ.get('TEST_MULTIPLE_PLATFORMS', 'false').lower() == 'true'
TEST_MULTIPLE_PLATFORMS_RELAY = os.environ.get('TEST_MULTIPLE_PLATFORMS_RELAY', 'false').lower() == 'true'
TEST_MULTIPLE_VERSIONS_EXPLICIT = os.environ.get('TEST_MULTIPLE_VERSIONS_EXPLICIT', 'true').lower() == 'true'
LIST_CHROMIUM_VERSIONS = ['130.0', '129.0', '128.0']
LIST_FIREFOX_VERSIONS = ['132.0', '131.0', '130.0', '129.0', '128.0']
LIST_PLATFORMS = ['Linux', None, 'Windows 11']

if not TEST_MULTIPLE_VERSIONS_EXPLICIT:
    LIST_CHROMIUM_VERSIONS.append(None)
    LIST_FIREFOX_VERSIONS.append(None)

if TEST_MULTIPLE_PLATFORMS_RELAY:
    # Replace index with None to macOS
    LIST_PLATFORMS[1] = 'macOS'

SELENIUM_GRID_URL = f"{SELENIUM_GRID_PROTOCOL}://{SELENIUM_GRID_HOST}:{SELENIUM_GRID_PORT}"
CLIENT_CONFIG = ClientConfig(
    remote_server_addr=SELENIUM_GRID_URL,
    keep_alive=True,
    timeout=3600,
    username=SELENIUM_GRID_USERNAME,
    password=SELENIUM_GRID_PASSWORD,
    ca_certs=CHART_CERT_PATH,
)

if TEST_NODE_RELAY == 'Android':
    time.sleep(90)


class SeleniumGenericTests(unittest.TestCase):

    def test_title(self):
        self.driver.get('https://the-internet.herokuapp.com')
        wait = WebDriverWait(self.driver, WEB_DRIVER_WAIT_TIMEOUT)
        wait.until(EC.title_is('The Internet'))
        self.assertTrue(self.driver.title == 'The Internet')

    # https://github.com/tourdedave/elemental-selenium-tips/blob/master/03-work-with-frames/python/frames.py
    def test_with_frames(self):
        driver = self.driver
        driver.get('http://the-internet.herokuapp.com/nested_frames')
        wait = WebDriverWait(driver, WEB_DRIVER_WAIT_TIMEOUT)
        frame_top = wait.until(EC.frame_to_be_available_and_switch_to_it('frame-top'))
        frame_middle = wait.until(EC.frame_to_be_available_and_switch_to_it('frame-middle'))
        self.assertTrue(driver.find_element(By.ID, 'content').text == "MIDDLE", "content should be MIDDLE")

    # https://github.com/tourdedave/elemental-selenium-tips/blob/master/05-select-from-a-dropdown/python/dropdown.py
    def test_select_from_a_dropdown(self):
        driver = self.driver
        driver.get('http://the-internet.herokuapp.com/dropdown')
        dropdown_list = driver.find_element(By.ID, 'dropdown')
        options = dropdown_list.find_elements(By.TAG_NAME, 'option')
        for opt in options:
            if opt.text == 'Option 1':
                opt.click()
                break
        for opt in options:
            if opt.is_selected():
                selected_option = opt.text
                break
        self.assertTrue(selected_option == 'Option 1', "Selected option should be Option 1")

    # https://github.com/tourdedave/elemental-selenium-tips/blob/master/13-work-with-basic-auth/python/basic_auth_1.py
    def test_visit_basic_auth_secured_page(self):
        driver = self.driver
        driver.get('http://admin:admin@the-internet.herokuapp.com/basic_auth')
        page_message = driver.find_element(By.CSS_SELECTOR, '.example p').text
        self.assertTrue(page_message == 'Congratulations! You must have the proper credentials.')

    def test_play_video(self):
        driver = self.driver
        driver.get('https://googleads.github.io/googleads-ima-html5/vsi/')
        wait = WebDriverWait(driver, WEB_DRIVER_WAIT_TIMEOUT)
        play_button = wait.until(EC.element_to_be_clickable((By.ID, 'play-button')))
        play_button.click()
        video = driver.find_element(By.TAG_NAME, 'video')
        wait.until(lambda d: d.find_element(By.TAG_NAME, 'video').get_property('currentTime'))
        wait.until(lambda d: d.find_element(By.TAG_NAME, 'video').get_property('paused') == False)
        paused = video.get_property('paused')
        self.assertFalse(paused)

    def test_download_file(self):
        driver = self.driver
        driver.get('https://the-internet.herokuapp.com/download')
        file_name = 'some-file.txt'
        wait = WebDriverWait(driver, 30)
        file_link = wait.until(EC.element_to_be_clickable((By.LINK_TEXT, file_name)))
        driver.execute_script("arguments[0].scrollIntoView();", file_link)
        file_link.click()
        if not SELENIUM_ENABLE_MANAGED_DOWNLOADS:
            time.sleep(4)
            return
        wait.until(lambda d: str(d.get_downloadable_files()[0]).endswith(file_name))
        self.assertTrue(str(driver.get_downloadable_files()[0]).endswith(file_name))

    def tearDown(self):
        if TEST_CUSTOM_SPECIFIC_NAME:
            self.assertTrue(str(self.driver.capabilities['myApp:version']) == 'beta')
            self.assertTrue(str(self.driver.capabilities['myApp:publish']) == 'internal')
        try:
            if TEST_DELAY_AFTER_TEST:
                time.sleep(TEST_DELAY_AFTER_TEST)
            self.driver.quit()
        except Exception as e:
            print(f"::error::Exception: {str(e)}")
            print(traceback.format_exc())
            raise e


class ChromeTests(SeleniumGenericTests):
    def setUp(self):
        try:
            options = ChromeOptions()
            options.enable_downloads = SELENIUM_ENABLE_MANAGED_DOWNLOADS
            if not SELENIUM_ENABLE_MANAGED_DOWNLOADS:
                options.add_argument('disable-features=DownloadBubble,DownloadBubbleV2')
            if TEST_ADD_CAPS_RECORD_VIDEO:
                options.set_capability('se:recordVideo', True)
            if TEST_CUSTOM_SPECIFIC_NAME:
                options.set_capability('myApp:version', 'beta')
                options.set_capability('myApp:publish', 'internal')
            options.set_capability('se:name', f"{self._testMethodName} ({self.__class__.__name__})")
            options.set_capability('se:screenResolution', '1920x1080')
            if SELENIUM_GRID_TEST_HEADLESS:
                options.add_argument('--headless=new')
            if TEST_MULTIPLE_VERSIONS:
                browser_version = random.choice(LIST_CHROMIUM_VERSIONS)
                if browser_version:
                    options.set_capability('browserVersion', browser_version)
                options.set_capability('platformName', LIST_PLATFORMS[0])
            if TEST_NODE_RELAY == 'Android':
                options.set_capability('platformName', TEST_NODE_RELAY)
                options.set_capability('appium:platformVersion', TEST_ANDROID_PLATFORM_API)
                options.set_capability('appium:deviceName', 'emulator-5554')
                options.set_capability('appium:automationName', 'uiautomator2')
                options.set_capability('appium:browserName', 'chrome')
                options.set_capability('appium:adbExecTimeout', 120000)
                options.set_capability('appium:uiautomator2ServerInstallTimeout', 120000)
                options.set_capability('appium:appWaitDuration', 120000)
                options.set_capability('appium:suppressKillServer', True)
                options.set_capability('appium:allowDelayAdb', False)
            if TEST_MULTIPLE_PLATFORMS:
                platform_name = random.choice(LIST_PLATFORMS)
                if platform_name:
                    options.set_capability('platformName', platform_name)
            if TEST_MULTIPLE_PLATFORMS_RELAY:
                options.set_capability(
                    'sauce:options',
                    {
                        'username': os.environ.get('SAUCE_USERNAME'),
                        'accessKey': os.environ.get('SAUCE_ACCESS_KEY'),
                        'name': f"{self._testMethodName} ({self.__class__.__name__})",
                        'seleniumVersion': '4.29.0',
                    },
                )
            start_time = time.time()
            self.driver = webdriver.Remote(
                options=options, command_executor=SELENIUM_GRID_URL, client_config=CLIENT_CONFIG
            )
            end_time = time.time()
            print(
                f"Begin: {self._testMethodName} ({self.__class__.__name__}) WebDriver initialization completed in {end_time - start_time} (s)"
            )
        except Exception as e:
            print(f"::error::Exception: {str(e)}")
            print(traceback.format_exc())
            raise e


class EdgeTests(SeleniumGenericTests):
    def setUp(self):
        try:
            options = EdgeOptions()
            options.enable_downloads = SELENIUM_ENABLE_MANAGED_DOWNLOADS
            if not SELENIUM_ENABLE_MANAGED_DOWNLOADS:
                options.add_argument('disable-features=DownloadBubble,DownloadBubbleV2')
            if TEST_ADD_CAPS_RECORD_VIDEO:
                options.set_capability('se:recordVideo', True)
            if TEST_CUSTOM_SPECIFIC_NAME:
                options.set_capability('myApp:version', 'beta')
                options.set_capability('myApp:publish', 'internal')
            options.set_capability('se:name', f"{self._testMethodName} ({self.__class__.__name__})")
            options.set_capability('se:screenResolution', '1920x1080')
            if SELENIUM_GRID_TEST_HEADLESS:
                options.add_argument('--headless=new')
            if TEST_MULTIPLE_VERSIONS:
                browser_version = random.choice(LIST_CHROMIUM_VERSIONS)
                if browser_version:
                    options.set_capability('browserVersion', browser_version)
                    options.set_capability('platformName', LIST_PLATFORMS[0])
            if TEST_MULTIPLE_PLATFORMS:
                platform_name = random.choice(LIST_PLATFORMS)
                if platform_name:
                    options.set_capability('platformName', platform_name)
            if TEST_MULTIPLE_PLATFORMS_RELAY:
                options.set_capability(
                    'sauce:options',
                    {
                        'username': os.environ.get('SAUCE_USERNAME'),
                        'accessKey': os.environ.get('SAUCE_ACCESS_KEY'),
                        'name': f"{self._testMethodName} ({self.__class__.__name__})",
                        'seleniumVersion': '4.29.0',
                    },
                )
            start_time = time.time()
            self.driver = webdriver.Remote(
                options=options, command_executor=SELENIUM_GRID_URL, client_config=CLIENT_CONFIG
            )
            end_time = time.time()
            print(
                f"Begin: {self._testMethodName} ({self.__class__.__name__}) WebDriver initialization completed in {end_time - start_time} (s)"
            )
        except Exception as e:
            print(f"::error::Exception: {str(e)}")
            print(traceback.format_exc())
            raise e


class FirefoxTests(SeleniumGenericTests):
    def setUp(self):
        try:
            profile = webdriver.FirefoxProfile()
            options = FirefoxOptions()
            options.enable_downloads = SELENIUM_ENABLE_MANAGED_DOWNLOADS
            if not SELENIUM_ENABLE_MANAGED_DOWNLOADS:
                profile.set_preference("browser.download.manager.showWhenStarting", False)
                profile.set_preference("browser.helperApps.neverAsk.saveToDisk", "*/*")
            profile.set_preference('intl.accept_languages', 'vi-VN,vi')
            profile.set_preference('intl.locale.requested', 'vi-VN,vi')
            options.profile = profile
            if TEST_ADD_CAPS_RECORD_VIDEO:
                options.set_capability('se:recordVideo', True)
            if TEST_CUSTOM_SPECIFIC_NAME:
                options.set_capability('myApp:version', 'beta')
                options.set_capability('myApp:publish', 'internal')
            options.set_capability('se:name', f"{self._testMethodName} ({self.__class__.__name__})")
            options.set_capability('se:screenResolution', '1920x1080')
            if SELENIUM_GRID_TEST_HEADLESS:
                options.add_argument('-headless')
            if TEST_MULTIPLE_VERSIONS:
                browser_version = random.choice(LIST_FIREFOX_VERSIONS)
                if browser_version:
                    options.set_capability('browserVersion', browser_version)
                    options.set_capability('platformName', LIST_PLATFORMS[0])
            if TEST_MULTIPLE_PLATFORMS:
                platform_name = random.choice(LIST_PLATFORMS)
                if platform_name:
                    options.set_capability('platformName', platform_name)
            if TEST_MULTIPLE_PLATFORMS_RELAY:
                options.set_capability(
                    'sauce:options',
                    {
                        'username': os.environ.get('SAUCE_USERNAME'),
                        'accessKey': os.environ.get('SAUCE_ACCESS_KEY'),
                        'name': f"{self._testMethodName} ({self.__class__.__name__})",
                        'seleniumVersion': '4.29.0',
                    },
                )
            start_time = time.time()
            self.driver = webdriver.Remote(
                options=options, command_executor=SELENIUM_GRID_URL, client_config=CLIENT_CONFIG
            )
            end_time = time.time()
            print(
                f"Begin: {self._testMethodName} ({self.__class__.__name__}) WebDriver initialization completed in {end_time - start_time} (s)"
            )
        except Exception as e:
            print(f"::error::Exception: {str(e)}")
            print(traceback.format_exc())
            raise e

    def test_title_and_maximize_window(self):
        self.driver.get('https://the-internet.herokuapp.com')
        self.driver.maximize_window()
        self.assertTrue(self.driver.title == 'The Internet')

    def test_accept_languages(self):
        if TEST_FIREFOX_INSTALL_LANG_PACKAGE:
            addon_id = webdriver.Firefox.install_addon(
                self.driver, "./target/firefox_lang_packs/langpack-vi@firefox.mozilla.org.xpi"
            )
        self.driver.get('https://gtranslate.io/detect-browser-language')
        wait = WebDriverWait(self.driver, WEB_DRIVER_WAIT_TIMEOUT)
        lang_code = wait.until(EC.presence_of_element_located((By.XPATH, '(//*[@class="notranslate"])[1]')))
        self.driver.execute_script("arguments[0].scrollIntoView();", lang_code)
        self.assertTrue(lang_code.text == 'vi-VN', "Language code should be vi-VN")
        time.sleep(1)
        self.driver.get('https://google.com')
        time.sleep(2)


class Autoscaling:
    def run(self, test_classes):
        with concurrent.futures.ThreadPoolExecutor() as executor:
            futures = []
            tests = []
            start_times = {}
            mixed_tests = []
            for test_class in test_classes:
                suite = unittest.TestLoader().loadTestsFromTestCase(test_class)
                mixed_tests.extend(suite)
                random.shuffle(mixed_tests)
            for test in mixed_tests:
                start_times[test] = time.time()
                futures.append(executor.submit(test))
                tests.append(test)
            print(f"Number of tests were added to worker: {len(tests)}")
            failed_tests = []
            for future, test in zip(concurrent.futures.as_completed(futures), tests):
                try:
                    completion_time = time.time() - start_times[test]
                    print(f"Finish: {str(test)} completed in {str(completion_time)} (s)")
                    if not future.result().wasSuccessful():
                        raise Exception
                except Exception as e:
                    failed_tests.append(test)
                    print(traceback.format_exc())
                    print(f"{str(test)} failed with exception: {str(e)}")
                    print(f"Original exception: {e.__cause__}")
            if len(failed_tests) > 0:
                print(f"Number of failed tests: {len(failed_tests)}. Going to rerun!")
                for test in failed_tests:
                    try:
                        print(f"Rerunning test: {str(test)}")
                        rerun_result = test.run()
                        if not rerun_result.wasSuccessful():
                            raise Exception
                    except Exception as e:
                        print(traceback.format_exc())
                        print(f"Test {str(test)} failed again with exception: {str(e)}")
                        print(f"Original exception: {e.__cause__}")
                        raise Exception(f"Rerun test failed: {str(test)} failed with exception: {str(e)}")
                print(f"::warning:: Number of failed tests: {len(failed_tests)}. All tests passed in rerun!")


class DeploymentAutoscalingTests(unittest.TestCase):
    def test_parallel_autoscaling(self):
        runner = Autoscaling()
        platform = TestPlatform()
        if not TEST_PARALLEL_HARDENING:
            runner.run(platform.add_test_based_platform(1))
        else:
            runner.run(platform.add_test_based_platform(TEST_PARALLEL_COUNT))


class JobAutoscalingTests(unittest.TestCase):
    def test_parallel_autoscaling(self):
        runner = Autoscaling()
        platform = TestPlatform()
        if not TEST_PARALLEL_HARDENING:
            runner.run(platform.add_test_based_platform(1))
        else:
            runner.run(platform.add_test_based_platform(TEST_PARALLEL_COUNT))


class TestPlatform:
    def add_test_based_platform(self, repeat):
        tests = []
        for i in range(repeat):
            if TEST_PLATFORMS == 'linux/amd64':
                tests.extend([FirefoxTests, ChromeTests, EdgeTests])
            else:
                tests.extend([FirefoxTests, ChromeTests])
        return tests
