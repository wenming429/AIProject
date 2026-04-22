// LumenIM API 性能测试脚本
// 使用方式: k6 run load-test.js
// 安装 k6: https://k6.io/docs/getting-started/installation/

import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// 自定义指标
const errorRate = new Rate('errors');
const loginDuration = new Trend('login_duration');
const messageDuration = new Trend('message_duration');
const healthDuration = new Trend('health_duration');

// 测试配置
export const options = {
  scenarios: {
    // 预热阶段
    warmup: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '30s', target: 10 },
      ],
    },
    // 正常负载
    normal_load: {
      executor: 'ramping-vus',
      startVUs: 10,
      stages: [
        { duration: '1m', target: 50 },
        { duration: '2m', target: 50 },
        { duration: '1m', target: 0 },
      ],
    },
    // 压力测试
    stress_test: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '30s', target: 100 },
        { duration: '1m', target: 100 },
        { duration: '30s', target: 0 },
      ],
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<500', 'p(99)<1000'],
    http_req_failed: ['rate<0.01'],
    errors: ['rate<0.1'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:9501/api/v1';

// 测试数据生成
function generateRandomUser() {
  const timestamp = Date.now();
  return {
    username: `loadtest_${timestamp}_${Math.floor(Math.random() * 10000)}`,
    password: 'Test123456',
    nickname: `测试用户${timestamp}`,
  };
}

function generateMessage() {
  const messages = [
    '这是一条负载测试消息',
    'Hello from k6 load test!',
    'Performance testing message',
    '🔔 测试通知',
    '随机消息 ' + Math.random().toString(36).substring(7),
  ];
  return messages[Math.floor(Math.random() * messages.length)];
}

// 主测试函数
export default function () {
  let token = null;
  const user = generateRandomUser();

  group('健康检查', () => {
    const start = Date.now();
    const res = http.get(`${BASE_URL}/health`);
    healthDuration.add(Date.now() - start);
    
    const success = check(res, {
      '健康检查 - 状态码200': (r) => r.status === 200,
      '健康检查 - 响应时间<500ms': (r) => r.timings.duration < 500,
      '健康检查 - 返回JSON': (r) => r.headers['Content-Type'].includes('json'),
    });
    errorRate.add(!success);
  });

  group('用户注册', () => {
    const res = http.post(
      `${BASE_URL}/user/register`,
      JSON.stringify(user),
      { headers: { 'Content-Type': 'application/json' } }
    );
    
    check(res, {
      '注册 - 状态码200或409': (r) => [200, 409].includes(r.status),
    });
  });

  group('用户登录', () => {
    const start = Date.now();
    const res = http.post(
      `${BASE_URL}/user/login`,
      JSON.stringify({
        username: 'testuser001',
        password: 'Test123456',
      }),
      { headers: { 'Content-Type': 'application/json' } }
    );
    loginDuration.add(Date.now() - start);
    
    const success = check(res, {
      '登录 - 状态码200': (r) => r.status === 200,
      '登录 - 响应包含token': (r) => {
        try {
          const body = JSON.parse(r.body);
          return body.data && body.data.token;
        } catch (e) {
          return false;
        }
      },
    });
    errorRate.add(!success);
    
    if (success) {
      try {
        const body = JSON.parse(res.body);
        token = body.data && body.data.token;
      } catch (e) {}
    }
  });

  if (token) {
    const headers = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`,
    };

    group('获取好友列表', () => {
      const res = http.get(`${BASE_URL}/friend/list`, { headers });
      
      check(res, {
        '好友列表 - 状态码200': (r) => r.status === 200,
      });
    });

    group('发送消息', () => {
      const start = Date.now();
      const res = http.post(
        `${BASE_URL}/message/send`,
        JSON.stringify({
          receiver_id: 1001,
          content: generateMessage(),
          msg_type: 'text',
        }),
        { headers }
      );
      messageDuration.add(Date.now() - start);
      
      check(res, {
        '发送消息 - 状态码正确': (r) => [200, 201, 400].includes(r.status),
      });
    });

    group('获取聊天记录', () => {
      const res = http.get(
        `${BASE_URL}/message/history?user_id=1001&limit=50`,
        { headers }
      );
      
      check(res, {
        '聊天记录 - 状态码200': (r) => r.status === 200,
      });
    });
  }

  // 模拟用户思考时间
  sleep(Math.random() * 2 + 0.5);
}

// 测试完成后的处理
export function handleSummary(data) {
  return {
    'stdout': textSummary(data, { indent: ' ', enableColors: true }),
    'summary.json': JSON.stringify(data, null, 2),
  };
}

function textSummary(data, options) {
  const indent = options.indent || '';
  const enableColors = options.enableColors || false;
  
  const red = enableColors ? '\x1b[31m' : '';
  const green = enableColors ? '\x1b[32m' : '';
  const yellow = enableColors ? '\x1b[33m' : '';
  const reset = enableColors ? '\x1b[0m' : '';
  
  let output = '\n';
  output += indent + '='.repeat(60) + '\n';
  output += indent + '  LumenIM API 负载测试报告\n';
  output += indent + '='.repeat(60) + '\n\n';
  
  // 统计数据
  const stats = data.metrics;
  
  output += indent + '📊 请求统计\n';
  output += indent + '-'.repeat(40) + '\n';
  output += indent + `  总请求数: ${stats.http_reqs?.values?.count || 0}\n`;
  output += indent + `  请求速率: ${stats.http_req_duration?.values?.rate || 0} req/s\n`;
  output += indent + `  失败率: ${((stats.http_req_failed?.values?.rate || 0) * 100).toFixed(2)}%\n\n`;
  
  output += indent + '⏱️ 响应时间 (ms)\n';
  output += indent + '-'.repeat(40) + '\n';
  output += indent + `  平均值: ${stats.http_req_duration?.values?.avg?.toFixed(2) || 0}\n`;
  output += indent + `  中位数: ${stats.http_req_duration?.values?.med?.toFixed(2) || 0}\n`;
  output += indent + `  p95: ${stats.http_req_duration?.values?.['p(95)']?.toFixed(2) || 0}\n`;
  output += indent + `  p99: ${stats.http_req_duration?.values?.['p(99)']?.toFixed(2) || 0}\n`;
  output += indent + `  最大值: ${stats.http_req_duration?.values?.max?.toFixed(2) || 0}\n\n`;
  
  // 自定义指标
  output += indent + '🎯 自定义指标\n';
  output += indent + '-'.repeat(40) + '\n';
  
  if (stats.health_duration) {
    output += indent + `  健康检查平均: ${stats.health_duration.values.avg.toFixed(2)}ms\n`;
  }
  if (stats.login_duration) {
    output += indent + `  登录平均: ${stats.login_duration.values.avg.toFixed(2)}ms\n`;
  }
  if (stats.message_duration) {
    output += indent + `  发消息平均: ${stats.message_duration.values.avg.toFixed(2)}ms\n`;
  }
  
  output += '\n' + indent + '='.repeat(60) + '\n';
  
  // 判断是否通过阈值
  const p95 = stats.http_req_duration?.values?.['p(95)'] || 0;
  const failedRate = stats.http_req_failed?.values?.rate || 0;
  
  if (p95 > 500 || failedRate > 0.01) {
    output += indent + red + '❌ 测试未通过阈值\n' + reset;
  } else {
    output += indent + green + '✅ 测试通过\n' + reset;
  }
  
  output += indent + '='.repeat(60) + '\n';
  
  return output;
}
