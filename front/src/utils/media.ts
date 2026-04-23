/**
 * 媒体资源 URL 处理工具
 * 用于将相对路径拼接为完整的媒体资源 URL
 */

/**
 * 获取媒体资源的基础 URL
 * 优先使用 VITE_MEDIA_URL 配置，否则使用 VITE_BASE_API
 */
export function getMediaBaseUrl(): string {
  // 如果配置了独立的媒体域名，使用该域名
  if (import.meta.env.VITE_MEDIA_URL) {
    return import.meta.env.VITE_MEDIA_URL
  }
  // 否则使用 API 基础 URL
  return import.meta.env.VITE_BASE_API
}

/**
 * 将相对路径转换为完整的媒体资源 URL
 * @param path 相对路径，如 /public/xxx.jpg
 * @returns 完整的媒体资源 URL
 */
export function getMediaUrl(path: string): string {
  if (!path) {
    return path
  }

  // 如果已经是完整 URL（包含协议），直接返回
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return path
  }

  // 拼接完整的媒体 URL
  const baseUrl = getMediaBaseUrl()
  const separator = baseUrl.endsWith('/') || path.startsWith('/') ? '' : '/'

  return `${baseUrl}${separator}${path}`
}

/**
 * 判断是否为相对路径
 * @param url URL字符串
 */
export function isRelativePath(url: string): boolean {
  if (!url) return false
  return !url.startsWith('http://') && !url.startsWith('https://') && url.startsWith('/')
}
