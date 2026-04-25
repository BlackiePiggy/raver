'use client';

import { FormEvent, useEffect, useMemo, useRef, useState } from 'react';
import Image from 'next/image';
import { Noto_Sans_SC, Space_Grotesk } from 'next/font/google';
import { preRegistrationAPI } from '@/lib/api/pre-registration';
import { CountryCallingOption, COUNTRY_CALLING_OPTIONS } from '@/lib/country-calling-codes';
import styles from './pre-register.module.css';

type Salutation = 'Miss.' | 'Mr.' | '先生' | '女士';

type PreRegistrationForm = {
  email: string;
  salutationName: string;
  phoneCountryIso2: string;
  phoneCountryCode: string;
  phoneNumber: string;
  wechatId: string;
  salutation: Salutation;
  expectationMessage: string;
};

type FormErrors = Partial<Record<keyof PreRegistrationForm, string>>;

type Feature = {
  id: string;
  tag: string;
  title: string;
  description: string;
  points: string[];
  effect: 'prism' | 'orbits' | 'grid' | 'signal' | 'constellation' | 'pulse';
};

const spaceGrotesk = Space_Grotesk({
  subsets: ['latin'],
  weight: ['400', '500', '600', '700'],
  variable: '--font-space',
});

const notoSansSC = Noto_Sans_SC({
  subsets: ['latin'],
  weight: ['400', '500', '700'],
  variable: '--font-cn',
});

const FEATURES: Feature[] = [
  {
    id: 'feature-1',
    tag: '01 / Intelligence Core',
    title: '智能编排内核',
    description: '把复杂流程拆成可执行节点，自动调度、自动恢复，让团队从“手工串流程”升级到“策略驱动”。',
    points: ['可视化工作流', '多阶段依赖编排', '失败自动重试与回滚'],
    effect: 'prism',
  },
  {
    id: 'feature-2',
    tag: '02 / Multi-Platform',
    title: '多端协同控制台',
    description: '同一条业务链路在 Web、移动端、API 渠道实时联动，确保上下游角色对齐。',
    points: ['统一任务状态', '跨端消息一致性', '角色视角切换'],
    effect: 'orbits',
  },
  {
    id: 'feature-3',
    tag: '03 / Observability',
    title: '实时可观测系统',
    description: '关键指标、链路延迟、异常信号集中展示，异常出现时秒级定位责任节点。',
    points: ['实时指标流', '异常追踪链路', '告警策略分层'],
    effect: 'grid',
  },
  {
    id: 'feature-4',
    tag: '04 / Agent Automation',
    title: 'Agent 自动化执行',
    description: '把重复任务交给智能 Agent，团队把精力留给策略、创意和高价值判断。',
    points: ['规则 + AI 混合执行', '上下文记忆', '任务结果审计'],
    effect: 'signal',
  },
  {
    id: 'feature-5',
    tag: '05 / Security & Governance',
    title: '权限与合规治理',
    description: '在高速迭代中保持安全边界，支持分级权限、操作审计与风险回放。',
    points: ['细粒度权限', '审计日志', '风险策略沙箱'],
    effect: 'constellation',
  },
  {
    id: 'feature-6',
    tag: '06 / Open Ecosystem',
    title: '开放 API 生态',
    description: '通过 API 和 Webhook 快速接入现有技术栈，把预注册用户沉淀为长期增长资产。',
    points: ['标准化 API', 'Webhook 事件总线', '生态插件化扩展'],
    effect: 'pulse',
  },
];

const emptyForm: PreRegistrationForm = {
  email: '',
  salutationName: '',
  phoneCountryIso2: 'CN',
  phoneCountryCode: '+86',
  phoneNumber: '',
  wechatId: '',
  salutation: '先生',
  expectationMessage: '',
};

const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const wechatRegex = /^[a-zA-Z0-9_-]{3,64}$/;

const validateForm = (form: PreRegistrationForm): FormErrors => {
  const errors: FormErrors = {};

  const email = form.email.trim().toLowerCase();
  if (!email) {
    errors.email = '邮箱为必填项';
  } else if (!emailRegex.test(email)) {
    errors.email = '邮箱格式不正确';
  }

  const salutationName = form.salutationName.trim();
  if (!salutationName) {
    errors.salutationName = '请填写称呼名（如：李）';
  } else if (!/^[\p{L}\p{N}·•\-\s]{1,32}$/u.test(salutationName)) {
    errors.salutationName = '称呼名格式不正确';
  }

  const phone = form.phoneNumber.trim();
  if (phone && !form.phoneCountryCode) {
    errors.phoneNumber = '填写手机号时请先选择国家区号';
  }

  if (form.phoneCountryCode && !/^\+\d{1,4}$/.test(form.phoneCountryCode)) {
    errors.phoneCountryCode = '区号格式应为 +XX';
  }

  const wechat = form.wechatId.trim();
  if (wechat && !wechatRegex.test(wechat)) {
    errors.wechatId = '微信号格式不正确';
  }

  if (form.expectationMessage.trim().length > 500) {
    errors.expectationMessage = '期望留言不能超过 500 字';
  }

  return errors;
};

export default function PreRegisterLanding() {
  const [form, setForm] = useState<PreRegistrationForm>(emptyForm);
  const [errors, setErrors] = useState<FormErrors>({});
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);
  const [submitResult, setSubmitResult] = useState<{ message: string; alreadyRegistered: boolean } | null>(null);
  const [countryMenuOpen, setCountryMenuOpen] = useState(false);
  const [countryQuery, setCountryQuery] = useState('');

  const [activeFeature, setActiveFeature] = useState(0);
  const [scrollProgress, setScrollProgress] = useState(0);
  const [offsets, setOffsets] = useState<number[]>(Array(FEATURES.length).fill(0));

  const sectionRefs = useRef<Array<HTMLElement | null>>([]);
  const countryMenuRef = useRef<HTMLDivElement | null>(null);
  const messageLength = useMemo(() => form.expectationMessage.trim().length, [form.expectationMessage]);
  const fullSalutationPreview = useMemo(() => {
    const name = form.salutationName.trim();
    return name ? `${name}${form.salutation}` : `示例：李${form.salutation}`;
  }, [form.salutation, form.salutationName]);
  const selectedCountry = useMemo<CountryCallingOption | undefined>(
    () =>
      COUNTRY_CALLING_OPTIONS.find((item) => item.iso2 === form.phoneCountryIso2)
      || COUNTRY_CALLING_OPTIONS.find((item) => item.callingCode === form.phoneCountryCode),
    [form.phoneCountryCode, form.phoneCountryIso2]
  );
  const filteredCountryOptions = useMemo(() => {
    const keyword = countryQuery.trim().toLowerCase();
    if (!keyword) return COUNTRY_CALLING_OPTIONS;
    return COUNTRY_CALLING_OPTIONS.filter((item) => {
      const tokens = `${item.name} ${item.iso2} ${item.callingCode}`.toLowerCase();
      return tokens.includes(keyword);
    });
  }, [countryQuery]);

  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return;
          const index = Number(entry.target.getAttribute('data-index') || 0);
          setActiveFeature(index);
        });
      },
      {
        threshold: 0.52,
      }
    );

    sectionRefs.current.forEach((el) => {
      if (el) observer.observe(el);
    });

    const onScroll = () => {
      const root = document.documentElement;
      const max = Math.max(1, root.scrollHeight - window.innerHeight);
      setScrollProgress(Math.min(1, Math.max(0, window.scrollY / max)));

      const nextOffsets = sectionRefs.current.map((el) => {
        if (!el) return 0;
        const rect = el.getBoundingClientRect();
        const center = rect.top + rect.height / 2;
        const distance = (window.innerHeight / 2 - center) / (window.innerHeight / 2);
        return Math.max(-1, Math.min(1, distance));
      });
      setOffsets(nextOffsets);
    };

    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });

    return () => {
      observer.disconnect();
      window.removeEventListener('scroll', onScroll);
    };
  }, []);

  useEffect(() => {
    if (!countryMenuOpen) return;
    const handlePointerDown = (event: MouseEvent) => {
      if (!countryMenuRef.current) return;
      if (!countryMenuRef.current.contains(event.target as Node)) {
        setCountryMenuOpen(false);
      }
    };
    const handleEscape = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setCountryMenuOpen(false);
      }
    };
    document.addEventListener('mousedown', handlePointerDown);
    document.addEventListener('keydown', handleEscape);
    return () => {
      document.removeEventListener('mousedown', handlePointerDown);
      document.removeEventListener('keydown', handleEscape);
    };
  }, [countryMenuOpen]);

  const handleCountrySelect = (item: CountryCallingOption) => {
    setForm((prev) => ({
      ...prev,
      phoneCountryIso2: item.iso2,
      phoneCountryCode: item.callingCode,
    }));
    setCountryMenuOpen(false);
    setCountryQuery('');
  };

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setSubmitError(null);

    const nextErrors = validateForm(form);
    setErrors(nextErrors);
    if (Object.keys(nextErrors).length > 0) return;

    setIsSubmitting(true);
    try {
      const response = await preRegistrationAPI.submit({
        email: form.email.trim().toLowerCase(),
        salutationName: form.salutationName.trim(),
        phoneCountryCode: form.phoneNumber.trim() ? form.phoneCountryCode : undefined,
        phoneNumber: form.phoneNumber.trim() || undefined,
        wechatId: form.wechatId.trim() || undefined,
        salutation: form.salutation,
        expectationMessage: form.expectationMessage.trim() || undefined,
        source: 'dedicated-preregister-site',
      });

      setSubmitResult({
        message: response.message,
        alreadyRegistered: response.alreadyRegistered,
      });
    } catch (error) {
      setSubmitError(error instanceof Error ? error.message : '提交失败，请稍后重试');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <main className={`${styles.page} ${spaceGrotesk.variable} ${notoSansSC.variable}`}>
      <div className={styles.progressTrack}>
        <span className={styles.progressFill} style={{ transform: `scaleX(${scrollProgress})` }} />
      </div>

      <header className={styles.hero}>
        <a href="/admin/pre-registrations" className={styles.adminEntry}>
          进入后台管理
        </a>
        <div className={styles.heroAura} />
        <div className={styles.heroGrid} />
        <div className={styles.heroContent}>
          <p className={styles.heroLabel}>PRIVATE BETA PROGRAM</p>
          <h1 className={styles.heroTitle}>RaveHub 电子音乐共建社区</h1>
          <p className={styles.heroSubtitle}>欢迎 Raver 们回家，下一代社区基础设施正在开启内测。</p>
          <p className={styles.heroNote}>
            内测名额将按批次抽取发放。提交预登记后，请等待抽取内测资格结果通知。
          </p>
          <div className={styles.heroActions}>
            <a href="#register" className={styles.primaryBtn}>去登记</a>
            <a href="#features" className={styles.ghostBtn}>查看能力分镜</a>
          </div>
        </div>
      </header>

      <section id="features" className={styles.featureSection}>
        <div className={styles.featureRail}>
          {FEATURES.map((feature, index) => (
            <button
              key={feature.id}
              type="button"
              className={`${styles.railDot} ${index === activeFeature ? styles.railDotActive : ''}`}
              onClick={() => sectionRefs.current[index]?.scrollIntoView({ behavior: 'smooth', block: 'center' })}
              aria-label={feature.title}
            />
          ))}
        </div>

        {FEATURES.map((feature, index) => {
          const motionOffset = offsets[index] || 0;
          return (
            <article
              key={feature.id}
              ref={(el) => {
                sectionRefs.current[index] = el;
              }}
              data-index={index}
              className={`${styles.featureCard} ${styles[`effect_${feature.effect}`]}`}
            >
              <div className={styles.featureText}>
                <p className={styles.featureTag}>{feature.tag}</p>
                <h2 className={styles.featureTitle}>{feature.title}</h2>
                <p className={styles.featureDesc}>{feature.description}</p>
                <ul className={styles.featurePoints}>
                  {feature.points.map((point) => (
                    <li key={`${feature.id}-${point}`}>{point}</li>
                  ))}
                </ul>
                <a href="#register" className={styles.inlineCta}>参与内测资格抽取</a>
              </div>

              <div className={styles.featureVisual} style={{ transform: `translateY(${motionOffset * 20}px)` }}>
                <div className={styles.visualShell}>
                  <div className={styles.visualCore} />
                  <div className={styles.visualLayerA} />
                  <div className={styles.visualLayerB} />
                  <div className={styles.visualLayerC} />
                </div>
              </div>
            </article>
          );
        })}
      </section>

      <section id="register" className={styles.registerSection}>
        <div className={styles.registerGlow} />
        <div className={styles.registerWrap}>
          <div className={styles.registerHeading}>
            <p className={styles.registerLabel}>BETA REGISTRATION</p>
            <h2>预登记内测资格</h2>
            <p>提交后将进入抽取池。我们会按批次抽取内测资格，并通过多端通知你结果。</p>
          </div>

          {submitResult ? (
            <div className={styles.successCard}>
              <p className={styles.successTitle}>预登记完成</p>
              <p className={styles.successMain}>{submitResult.message}</p>
              <p className={styles.successSub}>
                {submitResult.alreadyRegistered
                  ? '该邮箱已登记，我们已更新你的最新信息。请等待抽取内测资格。'
                  : '请等待抽取内测资格，名额有限，我们会尽快通知你。'}
              </p>
            </div>
          ) : (
            <form className={styles.form} onSubmit={handleSubmit}>
              <div className={styles.fieldBlock}>
                <label htmlFor="email">邮箱（必填）</label>
                <input
                  id="email"
                  type="email"
                  value={form.email}
                  onChange={(event) => setForm((prev) => ({ ...prev, email: event.target.value }))}
                  placeholder="you@example.com"
                />
                {errors.email && <p className={styles.error}>{errors.email}</p>}
              </div>

              <div className={styles.inlineFields}>
                <div className={styles.fieldBlock}>
                  <label htmlFor="salutationName">称呼名（必填）</label>
                  <input
                    id="salutationName"
                    type="text"
                    value={form.salutationName}
                    onChange={(event) => setForm((prev) => ({ ...prev, salutationName: event.target.value }))}
                    placeholder="例如：李"
                  />
                  {errors.salutationName && <p className={styles.error}>{errors.salutationName}</p>}
                </div>

                <div className={styles.fieldBlock}>
                  <label htmlFor="salutation">称呼后缀</label>
                  <select
                    id="salutation"
                    value={form.salutation}
                    onChange={(event) => setForm((prev) => ({ ...prev, salutation: event.target.value as Salutation }))}
                  >
                    <option value="Miss.">Miss.</option>
                    <option value="Mr.">Mr.</option>
                    <option value="先生">先生</option>
                    <option value="女士">女士</option>
                  </select>
                  <p className={styles.hint}>完整称呼：{fullSalutationPreview}</p>
                </div>
              </div>

              <div className={styles.inlineFields}>
                <div className={styles.fieldBlock}>
                  <label htmlFor="countryPickerButton">国家/地区（完整列表）</label>
                  <div className={styles.countryPicker} ref={countryMenuRef}>
                    <button
                      id="countryPickerButton"
                      type="button"
                      className={styles.countryTrigger}
                      onClick={() => {
                        setCountryMenuOpen((prev) => !prev);
                        if (!countryMenuOpen) {
                          setCountryQuery('');
                        }
                      }}
                      aria-haspopup="listbox"
                      aria-expanded={countryMenuOpen}
                    >
                      <span className={styles.countryTriggerMain}>
                        {selectedCountry ? (
                          <>
                            <Image
                              src={selectedCountry.flagUrl}
                              alt={`${selectedCountry.name} flag`}
                              width={24}
                              height={18}
                              className={styles.countryFlag}
                            />
                            <span className={styles.countryName}>{selectedCountry.name}</span>
                            <span className={styles.countryIso}>{selectedCountry.iso2}</span>
                          </>
                        ) : (
                          <span className={styles.countryName}>选择国家 / 地区</span>
                        )}
                      </span>
                      <span className={styles.countryCode}>
                        {selectedCountry?.callingCode || form.phoneCountryCode}
                      </span>
                    </button>

                    {countryMenuOpen && (
                      <div className={styles.countryPanel}>
                        <div className={styles.countrySearchWrap}>
                          <input
                            type="text"
                            value={countryQuery}
                            onChange={(event) => setCountryQuery(event.target.value)}
                            placeholder="搜索国家、ISO 或区号（如 CN / +86）"
                            className={styles.countrySearch}
                          />
                        </div>
                        <ul className={styles.countryList} role="listbox">
                          {filteredCountryOptions.length > 0 ? (
                            filteredCountryOptions.map((item) => {
                              const isActive = item.iso2 === form.phoneCountryIso2;
                              return (
                                <li key={`${item.iso2}-${item.callingCode}`}>
                                  <button
                                    type="button"
                                    className={`${styles.countryOption} ${isActive ? styles.countryOptionActive : ''}`}
                                    onClick={() => handleCountrySelect(item)}
                                  >
                                    <span className={styles.countryOptionMain}>
                                      <Image
                                        src={item.flagUrl}
                                        alt={`${item.name} flag`}
                                        width={24}
                                        height={18}
                                        className={styles.countryFlag}
                                      />
                                      <span className={styles.countryOptionName}>{item.name}</span>
                                      <span className={styles.countryOptionIso}>{item.iso2}</span>
                                    </span>
                                    <span className={styles.countryOptionCode}>{item.callingCode}</span>
                                  </button>
                                </li>
                              );
                            })
                          ) : (
                            <li className={styles.countryEmpty}>没有匹配国家，请更换关键词。</li>
                          )}
                        </ul>
                      </div>
                    )}
                  </div>
                  {errors.phoneCountryCode && <p className={styles.error}>{errors.phoneCountryCode}</p>}
                </div>

                <div className={styles.fieldBlock}>
                  <label htmlFor="phone">手机号（可选）</label>
                  <input
                    id="phone"
                    type="tel"
                    value={form.phoneNumber}
                    onChange={(event) => setForm((prev) => ({ ...prev, phoneNumber: event.target.value }))}
                    placeholder="13800138000"
                  />
                  {errors.phoneNumber && <p className={styles.error}>{errors.phoneNumber}</p>}
                </div>
              </div>

              <div className={styles.fieldBlock}>
                <label htmlFor="wechat">微信号（可选）</label>
                <input
                  id="wechat"
                  type="text"
                  value={form.wechatId}
                  onChange={(event) => setForm((prev) => ({ ...prev, wechatId: event.target.value }))}
                  placeholder="wechat_id"
                />
                {errors.wechatId && <p className={styles.error}>{errors.wechatId}</p>}
              </div>

              <div className={styles.fieldBlock}>
                <label htmlFor="message">对产品的期望留言（可选）</label>
                <textarea
                  id="message"
                  rows={5}
                  value={form.expectationMessage}
                  onChange={(event) => setForm((prev) => ({ ...prev, expectationMessage: event.target.value }))}
                  placeholder="你希望这个产品率先解决什么问题？"
                />
                <div className={styles.metaLine}>
                  <span>提交即表示同意我们联系你并告知内测资格抽取结果。</span>
                  <span>{messageLength}/500</span>
                </div>
                {errors.expectationMessage && <p className={styles.error}>{errors.expectationMessage}</p>}
              </div>

              {submitError && <div className={styles.submitError}>{submitError}</div>}

              <button type="submit" disabled={isSubmitting} className={styles.submitBtn}>
                {isSubmitting ? '提交中...' : '提交预登记'}
              </button>
            </form>
          )}
        </div>
      </section>
    </main>
  );
}
