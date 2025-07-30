package service

import (
	"encoding/json"
	"errors"
	"math/rand"
	"sync"
	"time"

	"x-ui/logger"
	"x-ui/xray"

	"go.uber.org/atomic"
)

var (
	p                 *xray.Process
	lock              sync.Mutex
	isNeedXrayRestart atomic.Bool
	result            string
)

type XrayService struct {
	inboundService InboundService
	settingService SettingService
	xrayAPI        xray.XrayAPI
}

func (s *XrayService) IsXrayRunning() bool {
	return p != nil && p.IsRunning()
}

func (s *XrayService) GetXrayErr() error {
	if p == nil {
		return nil
	}
	return p.GetErr()
}

func (s *XrayService) GetXrayResult() string {
	if result != "" {
		return result
	}
	if s.IsXrayRunning() {
		return ""
	}
	if p == nil {
		return ""
	}
	result = p.GetResult()
	return result
}

func (s *XrayService) GetXrayVersion() string {
	if p == nil {
		return "Unknown"
	}
	return p.GetVersion()
}

func RemoveIndex(s []any, index int) []any {
	return append(s[:index], s[index+1:]...)
}

func (s *XrayService) GetXrayConfig() (*xray.Config, error) {
	templateConfig, err := s.settingService.GetXrayConfigTemplate()
	if err != nil {
		return nil, err
	}

	xrayConfig := &xray.Config{}
	err = json.Unmarshal([]byte(templateConfig), xrayConfig)
	if err != nil {
		return nil, err
	}

	s.inboundService.AddTraffic(nil, nil)

	inbounds, err := s.inboundService.GetAllInbounds()
	if err != nil {
		return nil, err
	}
	for _, inbound := range inbounds {
		if !inbound.Enable {
			continue
		}
		// get settings clients
		settings := map[string]any{}
		json.Unmarshal([]byte(inbound.Settings), &settings)
		clients, ok := settings["clients"].([]any)
		if ok {
			// check users active or not
			clientStats := inbound.ClientStats
			for _, clientTraffic := range clientStats {
				indexDecrease := 0
				for index, client := range clients {
					c := client.(map[string]any)
					if c["email"] == clientTraffic.Email {
						if !clientTraffic.Enable {
							clients = RemoveIndex(clients, index-indexDecrease)
							indexDecrease++
							logger.Infof("Remove Inbound User %s due to expiration or traffic limit", c["email"])
						}
					}
				}
			}

			// clear client config for additional parameters
			var final_clients []any
			for _, client := range clients {
				c := client.(map[string]any)
				if c["enable"] != nil {
					if enable, ok := c["enable"].(bool); ok && !enable {
						continue
					}
				}
				for key := range c {
					if key != "email" && key != "id" && key != "password" && key != "flow" && key != "method" {
						delete(c, key)
					}
					// 保留xtls-rprx-vision-udp443流控设置，不再转换为xtls-rprx-vision
					// 如果需要使用vision-udp443流控，请保留此配置
					// if c["flow"] == "xtls-rprx-vision-udp443" {
					//     c["flow"] = "xtls-rprx-vision"
					// }
				}
				final_clients = append(final_clients, any(c))
			}

			settings["clients"] = final_clients
			modifiedSettings, err := json.MarshalIndent(settings, "", "  ")
			if err != nil {
				return nil, err
			}

			inbound.Settings = string(modifiedSettings)
		}

		if len(inbound.StreamSettings) > 0 {
			// Unmarshal stream JSON
			var stream map[string]any
			json.Unmarshal([]byte(inbound.StreamSettings), &stream)

			// 确保正确处理REALITY协议设置
			if security, ok := stream["security"].(string); ok && security == "reality" {
				realitySettings, ok2 := stream["realitySettings"].(map[string]any)
				if ok2 {
					// 保留REALITY协议所需的所有字段
					stream["realitySettings"] = realitySettings
				}
			}

			// 处理TCP增强混淆
			if network, ok := stream["network"].(string); ok {
				if network == "tcp" {
					tcpSettings, ok := stream["tcpSettings"].(map[string]any)
					if ok {
						enhancedObfuscation, hasEnhanced := tcpSettings["enhancedObfuscation"].(bool)
						if hasEnhanced && enhancedObfuscation {
							// 增强混淆处理逻辑
							if tcpSettings["header"] != nil {
								header := tcpSettings["header"].(map[string]any)
								if headerType, ok := header["type"].(string); ok && headerType == "http" {
									// 增加额外的随机HTTP头以增强混淆
									if request, hasRequest := header["request"].(map[string]any); hasRequest {
										if headers, hasHeaders := request["headers"].(map[string]any); hasHeaders {
											// 添加更多随机HTTP头
											randomHeaders := map[string]any{
												"Accept-Encoding": []string{"gzip, deflate, br"},
												"Cache-Control": []string{"max-age=0"},
												"Connection": []string{"keep-alive"},
												"Sec-Fetch-Dest": []string{"document"},
												"Sec-Fetch-Mode": []string{"navigate"},
												"Sec-Fetch-Site": []string{"none"},
												"Sec-Fetch-User": []string{"?1"},
												"Upgrade-Insecure-Requests": []string{"1"},
												"sec-ch-ua": []string{"\"Google Chrome\";v=\"113\", \"Chromium\";v=\"113\""},
												"sec-ch-ua-mobile": []string{"?0"},
												"sec-ch-ua-platform": []string{"\"Windows\""},
											}

											// 合并随机头
											for k, v := range randomHeaders {
												if _, exists := headers[k]; !exists {
													headers[k] = v
												}
											}
											request["headers"] = headers
										}
									}
								}
							}
						}
						stream["tcpSettings"] = tcpSettings
					}
				}
			}

			// 处理KCP增强混淆
			if network == "kcp" {
				kcpSettings, ok := stream["kcpSettings"].(map[string]any)
				if ok {
					enhancedObfuscation, hasEnhanced := kcpSettings["enhancedObfuscation"].(bool)
					if hasEnhanced && enhancedObfuscation {
						// KCP增强混淆处理逻辑
						// 1. 随机生成更复杂的seed
						if _, hasSeed := kcpSettings["seed"].(string); hasSeed {
							// 生成更长更复杂的种子
							kcpSettings["seed"] = RandomString(16)
						}

						// 2. 调整MTU和TTI以增强混淆
						kcpSettings["mtu"] = 1200 // 使用非默认值
						kcpSettings["tti"] = 30   // 使用非默认值

						// 3. 确保使用拥塞控制
						kcpSettings["congestion"] = true

						// 4. 增加读写缓冲区大小
						kcpSettings["readBufferSize"] = 4
						kcpSettings["writeBufferSize"] = 4
					}
					stream["kcpSettings"] = kcpSettings
				}
			}

			delete(stream, "externalProxy")

			newStream, err := json.MarshalIndent(stream, "", "  ")
			if err != nil {
				return nil, err
			}
			inbound.StreamSettings = string(newStream)
		}

		inboundConfig := inbound.GenXrayInboundConfig()
		xrayConfig.InboundConfigs = append(xrayConfig.InboundConfigs, *inboundConfig)
	}
	return xrayConfig, nil
}

func (s *XrayService) GetXrayTraffic() ([]*xray.Traffic, []*xray.ClientTraffic, error) {
	if !s.IsXrayRunning() {
		err := errors.New("xray is not running")
		logger.Debug("Attempted to fetch Xray traffic, but Xray is not running:", err)
		return nil, nil, err
	}
	apiPort := p.GetAPIPort()
	s.xrayAPI.Init(apiPort)
	defer s.xrayAPI.Close()

	traffic, clientTraffic, err := s.xrayAPI.GetTraffic(true)
	if err != nil {
		logger.Debug("Failed to fetch Xray traffic:", err)
		return nil, nil, err
	}
	return traffic, clientTraffic, nil
}

func (s *XrayService) RestartXray(isForce bool) error {
	lock.Lock()
	defer lock.Unlock()
	logger.Debug("restart xray, force:", isForce)

	xrayConfig, err := s.GetXrayConfig()
	if err != nil {
		return err
	}

	if s.IsXrayRunning() {
		if !isForce && p.GetConfig().Equals(xrayConfig) {
			logger.Debug("It does not need to restart xray")
			return nil
		}
		p.Stop()
	}

	p = xray.NewProcess(xrayConfig)
	result = ""
	err = p.Start()
	if err != nil {
		return err
	}
	return nil
}

func (s *XrayService) StopXray() error {
	lock.Lock()
	defer lock.Unlock()
	logger.Debug("Attempting to stop Xray...")
	if s.IsXrayRunning() {
		return p.Stop()
	}
	return errors.New("xray is not running")
}

func (s *XrayService) SetToNeedRestart() {
	isNeedXrayRestart.Store(true)
}

func (s *XrayService) IsNeedRestartAndSetFalse() bool {
	return isNeedXrayRestart.CompareAndSwap(true, false)
}

// RandomString 生成指定长度的随机字符串
func RandomString(length int) string {
	rand.Seed(time.Now().UnixNano())
	const charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	b := make([]byte, length)
	for i := range b {
		b[i] = charset[rand.Intn(len(charset))]
	}
	return string(b)
}
