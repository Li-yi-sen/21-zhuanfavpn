import requests
import time
import traceback

def check_panel():
    print("开始检查...")
    url = "http://localhost:2053/"
    try:
        print(f"尝试访问: {url}")
        response = requests.get(url, timeout=5)
        print(f"状态码: {response.status_code}")
        print(f"内容: {response.text[:200]}...")
        return True
    except Exception as e:
        print(f"访问失败: {str(e)}")
        print("详细错误:")
        traceback.print_exc()
        return False

if __name__ == "__main__":
    print("正在检查3x-ui面板是否可访问...")
    for i in range(3):
        print(f"尝试 {i+1}/3")
        if check_panel():
            print("面板可以访问！")
            break
        else:
            print(f"尝试 {i+1}/3 失败，等待5秒后重试...")
            time.sleep(5)
    else:
        print("无法访问面板，请检查容器日志和配置。") 