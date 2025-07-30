package common

import (
	"errors"
	"fmt"

	"x-ui/logger"
)

func NewErrorf(format string, a ...any) error {
	msg := fmt.Sprintf(format, a...)
	return errors.New(msg)
}

func NewError(a ...any) error {
	msg := fmt.Sprintln(a...)
	return errors.New(msg)
}

func Recover(msg string) any {
	panicErr := recover()
	if panicErr != nil {
		if msg != "" {
			logger.Error(msg, "panic:", panicErr)
		}
	}
	return panicErr
}

// Combine 组合多个错误为一个错误
func Combine(errs ...error) error {
	var nonNilErrs []error
	for _, err := range errs {
		if err != nil {
			nonNilErrs = append(nonNilErrs, err)
		}
	}
	if len(nonNilErrs) == 0 {
		return nil
	}
	if len(nonNilErrs) == 1 {
		return nonNilErrs[0]
	}
	errMsg := "multiple errors: "
	for i, err := range nonNilErrs {
		if i > 0 {
			errMsg += ", "
		}
		errMsg += err.Error()
	}
	return errors.New(errMsg)
}
