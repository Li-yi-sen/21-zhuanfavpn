package network

import (
	"bufio"
	"bytes"
	"fmt"
	"net"
	"net/http"
	"strings"
	"sync"
)

type AutoHttpsConn struct {
	net.Conn

	firstBuf []byte
	bufStart int

	readRequestOnce sync.Once
}

func NewAutoHttpsConn(conn net.Conn) net.Conn {
	return &AutoHttpsConn{
		Conn: conn,
	}
}

func (c *AutoHttpsConn) readRequest() bool {
	c.firstBuf = make([]byte, 2048)
	n, err := c.Conn.Read(c.firstBuf)
	c.firstBuf = c.firstBuf[:n]
	if err != nil {
		return false
	}
	reader := bytes.NewReader(c.firstBuf)
	bufReader := bufio.NewReader(reader)
	request, err := http.ReadRequest(bufReader)
	if err != nil {
		return false
	}
	
	// 检测是否来自宝塔面板的代理请求
	isPanelProxy := false
	xForwardedProto := request.Header.Get("X-Forwarded-Proto")
	xForwardedFor := request.Header.Get("X-Forwarded-For")
	
	// 如果请求已经通过HTTPS代理，不再进行重定向
	if xForwardedProto == "https" || strings.HasPrefix(request.Header.Get("X-Forwarded-Host"), "https") {
		isPanelProxy = true
	}
	
	// 如果检测到是宝塔面板的代理请求，直接返回，不进行重定向
	if isPanelProxy || xForwardedFor != "" {
		return false
	}
	
	resp := http.Response{
		Header: http.Header{},
	}
	resp.StatusCode = http.StatusTemporaryRedirect
	location := fmt.Sprintf("https://%v%v", request.Host, request.RequestURI)
	resp.Header.Set("Location", location)
	resp.Write(c.Conn)
	c.Close()
	c.firstBuf = nil
	return true
}

func (c *AutoHttpsConn) Read(buf []byte) (int, error) {
	c.readRequestOnce.Do(func() {
		c.readRequest()
	})

	if c.firstBuf != nil {
		n := copy(buf, c.firstBuf[c.bufStart:])
		c.bufStart += n
		if c.bufStart >= len(c.firstBuf) {
			c.firstBuf = nil
		}
		return n, nil
	}

	return c.Conn.Read(buf)
}
