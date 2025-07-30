package middleware

import (
	"net"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

func DomainValidatorMiddleware(domain string) gin.HandlerFunc {
	return func(c *gin.Context) {
		// 如果没有设置域名限制，跳过验证
		if domain == "" {
			c.Next()
			return
		}
		
		// 获取原始Host
		host := c.Request.Host
		if colonIndex := strings.LastIndex(host, ":"); colonIndex != -1 {
			host, _, _ = net.SplitHostPort(c.Request.Host)
		}
		
		// 检查是否为本地请求
		if host == "localhost" || host == "127.0.0.1" || strings.HasPrefix(host, "192.168.") || 
		   strings.HasPrefix(host, "10.") || strings.HasPrefix(host, "172.") {
			c.Next()
			return
		}
		
		// 从X-Forwarded-Host头中获取主机名（宝塔反向代理场景）
		forwardedHost := c.GetHeader("X-Forwarded-Host")
		if forwardedHost != "" {
			if colonIndex := strings.LastIndex(forwardedHost, ":"); colonIndex != -1 {
				forwardedHost, _, _ = net.SplitHostPort(forwardedHost)
			}
			
			// 检查转发的主机名是否匹配
			if forwardedHost == domain {
				c.Next()
				return
			}
		}
		
		// 检查原始主机名是否匹配
		if host == domain {
			c.Next()
			return
		}
		
		// 允许通过子域名访问
		if strings.HasSuffix(host, "."+domain) {
			c.Next()
			return
		}
		
		c.AbortWithStatus(http.StatusForbidden)
	}
}
