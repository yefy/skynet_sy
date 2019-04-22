local errors = {}

local function add(error)
	assert(errors[error.code] == nil, string.format("had the same error code[%x], msg[%s]", error.code, error.message))
	errors[error.code] = error.message
	return error.code
end

--系统错误码
systemError = {
	success 				= add{code = 0, message = "成功"},
	invalid 				= add{code = -1, message = "未知错误"},
	invalidServer 			= add{code = -2, message = "服务不存在"},
	invalidCommand 			= add{code = -3, message = "命令不存在"},
	invalidRet 				= add{code = -4, message = "返回值不存在"},
}