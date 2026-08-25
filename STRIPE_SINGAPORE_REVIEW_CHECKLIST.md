# US Gift Card Hub — Stripe 新加坡商户审核资料与网站公开信息清单

> 用途：供公司负责人、合规人员和 Stripe 账户负责人准备审核资料。
> 范围：本文只列出需要由公司提供、提交给 Stripe，或需要在网站公开展示的信息；不包含网站建设方的程序开发、页面制作和部署任务。

## 一、重要前提：礼品卡属于 Stripe 受限业务

US Gift Card Hub 拟销售第三方品牌数字礼品卡。Stripe 将预付卡、礼品卡、虚拟额度及其他储值产品列入受限业务，需要额外尽调。公司注册、网站完整和普通 KYC 通过，并不代表该业务一定会获批。

正式收款前，应通过 Stripe Dashboard 的官方支持渠道，如实说明以下业务性质并取得审核结论：

- 经营主体为新加坡注册公司；
- 销售第三方品牌的美国区数字礼品卡；
- 礼品卡来源、供应商类型及采购方式；
- 公司是否获得合法采购和转售授权；
- 收款、风控、卡密交付、售后和退款流程；
- 预计客单价、月交易额及主要客户所在国家或地区。

不得将礼品卡业务笼统申报为普通“数字商品”、软件服务或其他不相符的业务类别。Stripe 最终是否支持该业务，以账户审核结果为准。

## 二、信息公开与提交范围

| 标记 | 含义 |
| --- | --- |
| **网站公开** | 消费者和 Stripe 审核人员无需登录即可查看 |
| **Stripe 私密提交** | 仅通过 Stripe Dashboard 或 Stripe 官方要求的安全入口提交 |
| **网站与 Stripe 一致** | 网站、ACRA、Stripe、银行账户及合同中的主体信息必须相互对应 |
| **按要求补充** | 不是所有账户都会被要求，但礼品卡业务应预先准备 |

身份证件、个人住址证明、活体认证、银行流水、完整银行账号、Stripe 密钥和 Webhook Secret 不得公开在网站，也不应通过普通邮件或聊天工具传递。

## 三、网站需要公开展示的信息

### 3.1 经营主体及网站归属

| 状态 | 公开信息 | 要求 | 属性 |
| --- | --- | --- | --- |
| [ ] | 品牌名称 | `US Gift Card Hub`，与 Stripe 中的 DBA/商业名称一致 | 网站公开、网站与 Stripe 一致 |
| [ ] | 公司法定英文全名 | 必须与 ACRA BizFile 和 Stripe 法定实体名称完全一致 | 网站公开、网站与 Stripe 一致 |
| [ ] | 品牌与公司的关系 | 明确说明网站由该新加坡公司运营 | 网站公开、网站与 Stripe 一致 |
| [ ] | UEN | 建议公开展示，用于将网站与 ACRA 登记主体建立清晰关联 | 网站公开、网站与 Stripe 一致 |
| [ ] | 公司地址 | 展示注册办公地址或可用于业务联系的有效地址；必须与 Stripe 申报信息可解释地对应 | 网站公开、网站与 Stripe 一致 |
| [ ] | 正式网站域名 | 必须为公司控制的公开可访问 HTTPS 域名 | 网站公开、网站与 Stripe 一致 |

建议使用统一的英文主体声明：

> US Gift Card Hub is operated by **[LEGAL COMPANY NAME]**, a company registered in Singapore under UEN **[UEN]**, with its registered office at **[REGISTERED ADDRESS]**.

该声明至少应出现在网站页脚、About Us、Terms of Service 和 Privacy Policy 中。

### 3.2 客服和消费者联系信息

| 状态 | 公开信息 | 要求 |
| --- | --- | --- |
| [ ] | 客服邮箱 | 建议使用网站域名邮箱，例如 `support@[domain]` |
| [ ] | 客服电话 | 可直接联系公司的有效号码，建议提供新加坡号码 |
| [ ] | 即时联系渠道 | WhatsApp、在线客服或其他直接沟通渠道之一 |
| [ ] | 客服时间 | 标明时区，例如 `Monday–Friday, 09:00–18:00 SGT` |
| [ ] | 回复时效 | 例如“一般咨询在1个工作日内回复” |
| [ ] | 退款或争议联系方法 | 明确退款申请应发送到哪个邮箱或入口 |

仅放置一个没有直接联系方式的网页表单通常不足。Stripe 建议提供多个联系方法，并至少包含邮箱、电话、实时聊天等直接沟通渠道。

### 3.3 商品和价格信息

网站应针对每个实际销售的礼品卡公开以下信息：

- [ ] 品牌及礼品卡准确名称；
- [ ] 数字礼品卡或实体礼品卡类型；
- [ ] 可购买的实际面额；
- [ ] 最终销售价格；
- [ ] 明确标注币种为 `USD`，不能只使用 `$` 符号；
- [ ] 适用国家、账户地区和兑换地区；
- [ ] 兑换条件、兑换入口和主要限制；
- [ ] 有效期及余额有效规则；
- [ ] 是否可叠加、转让或分次使用；
- [ ] 付款后交付方式；
- [ ] 正常交付时效；
- [ ] 延迟交付的处理方法；
- [ ] 无效卡、错误卡或已兑换卡的处理方法；
- [ ] 卡密交付后的退款限制；
- [ ] 礼品卡品牌方与本网站的关系或非隶属关系声明。

公开商品描述必须与提交给 Stripe 的产品和业务描述一致，不得使用演示价格、演示库存或无法交付的占位商品作为审核内容。

### 3.4 必须公开的政策和法律文本

#### Terms of Service

- [ ] 合同经营主体的法定公司名和 UEN；
- [ ] 网站品牌与公司的关系；
- [ ] 用户资格和账户责任；
- [ ] 商品性质、价格、币种和付款条件；
- [ ] 数字礼品卡地区及兑换限制；
- [ ] 交付、退款、取消和争议处理规则；
- [ ] 禁止盗刷、洗钱、套现、滥用和欺诈；
- [ ] 责任限制；
- [ ] 适用法律和争议解决方式；
- [ ] 公司联系地址和客服方式；
- [ ] 政策生效日期及更新日期。

#### Privacy Policy

- [ ] 数据控制者的公司法定名称、UEN和联系地址；
- [ ] 收集的数据类型，例如姓名、邮箱、IP、设备信息、订单和交付记录；
- [ ] 收集和使用数据的目的；
- [ ] 与 Stripe、供应商、邮件服务商及其他服务商共享数据的范围；
- [ ] Cookie、分析或广告技术的使用情况；
- [ ] 数据保存期限或确定期限的标准；
- [ ] 数据安全措施；
- [ ] 用户访问、更正或删除数据的方式；
- [ ] 跨境数据处理说明；
- [ ] 隐私联系邮箱；
- [ ] 政策生效日期及更新日期。

#### Refund Policy

- [ ] 哪些情况可以退款；
- [ ] 哪些情况不能退款；
- [ ] 卡密未交付、错误、无效或已被兑换时分别如何处理；
- [ ] 退款申请期限；
- [ ] 用户需要提供的订单和问题证据；
- [ ] 审核退款申请所需时间；
- [ ] 批准后原路退款及到账时间；
- [ ] 退款联系渠道；
- [ ] 公司法定名称及责任主体。

#### Digital Delivery Policy

- [ ] 卡密通过账户、邮件、API或人工方式交付；
- [ ] 正常交付时效；
- [ ] 人工审核可能造成的延迟；
- [ ] 客户未收到卡密时的处理方法；
- [ ] 交付完成的判定方式；
- [ ] 订单和交付记录的保存方式；
- [ ] 客服联系方法。

#### Cancellation and Return Policy

- [ ] 付款前能否取消；
- [ ] 付款后、卡密发出前能否取消；
- [ ] 卡密发出后能否取消；
- [ ] 数字商品不适用实体退货时，应明确说明；
- [ ] 无效或错误卡密不应仅以“不可退货”拒绝处理，应说明核验和补发或退款流程。

#### Region, Legal and Export Restrictions

- [ ] 美国区礼品卡的账户地区要求；
- [ ] 兑换国家、网络地区或币种限制；
- [ ] 禁止销售或使用的国家、地区和人员范围；
- [ ] 用户有责任确认账户资格的说明；
- [ ] 违反品牌方规则、制裁或法律要求时的订单处理方式。

#### Promotions, Tax and Invoice Information

- [ ] 优惠码、折扣、赠送或促销的完整条件；
- [ ] 活动起止时间和适用商品；
- [ ] 是否允许叠加优惠；
- [ ] 商品价格是否包含适用税费；
- [ ] 公司是否注册 GST；如已注册，展示适用的 GST 信息；
- [ ] 客户申请订单凭证或发票的方式。

### 3.5 支付安全公开说明

- [ ] 说明银行卡付款由 Stripe 安全处理；
- [ ] 说明网站不直接保存完整银行卡号码或 CVC；
- [ ] 展示实际接受的银行卡品牌或支付方式；
- [ ] 在付款前提供 Terms、Privacy、Refund 和 Delivery Policy 链接；
- [ ] 账单描述符应与 `US Gift Card Hub` 或公司公开品牌容易对应，避免消费者无法识别交易。

除非公司已经完成相应合规工作，不应笼统声称“本公司通过 PCI 认证”。可以准确说明支付页面由 Stripe 托管、支付资料由 Stripe 处理。

## 四、需要提交给 Stripe 的新加坡公司资料

以下材料原则上只通过 Stripe Dashboard 私密提交。

### 4.1 公司身份和登记资料

| 状态 | 资料 | 要求 |
| --- | --- | --- |
| [ ] | 公司法定英文全名 | 与 ACRA、银行账户和网站一致 |
| [ ] | UEN | 与 ACRA 记录一致 |
| [ ] | 公司法律实体类型 | 例如新加坡 Private Company |
| [ ] | 最新 ACRA BizFile | Stripe 无法自动匹配或要求补件时提交 |
| [ ] | Certificate of Incorporation | 按 Stripe 要求提交 |
| [ ] | Company Constitution | 按 Stripe 要求提交 |
| [ ] | 注册地址 | 与 ACRA 记录一致 |
| [ ] | 实际经营地址 | 如果不同于注册地址，应如实说明 |
| [ ] | 经营地址证明 | 租赁协议、水电网账单、税务或政府文件等 |
| [ ] | 公司联系电话 | 有效且可验证 |
| [ ] | 网站 URL | 公开、可访问、无密码和地区屏蔽 |
| [ ] | 网站控制权证明 | Stripe 要求验证网站所有权时提交 |
| [ ] | 业务和产品描述 | 必须明确写明第三方数字礼品卡销售模式 |

如果 Stripe 要求补充文件，文件中的公司名称、地址和注册编号必须与 Stripe 账户完全匹配。存在差异时，应先解释或更正，不能使用另一家公司或个人的资料替代。

### 4.2 Stripe 账户负责人

- [ ] 负责人英文姓名；
- [ ] 负责人职务；
- [ ] 负责人是否在 ACRA BizFile 中列为 Owner、Director、Managing Director、CEO 或其他受认可的关键职务；
- [ ] 政府签发的身份证明；
- [ ] 个人住址证明；
- [ ] Singpass MyInfo 或 Stripe Identity 活体认证；
- [ ] 负责人联系方式；
- [ ] 如果负责人不是可直接代表公司的关键人员，准备由董事或 CEO 签署的 Letter of Authorisation；
- [ ] 授权人身份证明；
- [ ] 授权书日期在 Stripe 接受期限内，通常应为近12个月。

### 4.3 董事和最终受益人

- [ ] 全部董事的英文姓名和身份信息；
- [ ] 直接或间接持股达到25%的所有自然人最终受益人；
- [ ] 每位受益人的直接和间接持股比例；
- [ ] 如果没有任何自然人持股达到25%，按 Stripe 要求提供董事或其他控制人的资料；
- [ ] 如果股东包括控股公司，提供完整股权链；
- [ ] 控股公司的注册文件；
- [ ] 多层持股结构的 Letter of Attestation 或其他证明；
- [ ] Stripe 要求的董事或所有人身份证明。

Stripe 会使用 ACRA 等政府登记信息进行匹配。如果 Stripe 账户中的董事、负责人或股权信息与登记信息不一致，可能要求提供近12个月签发或公证的政府文件、会议记录、董事证明或授权声明。

### 4.4 公司银行账户和财务资料

- [ ] 用于 Stripe 结算的公司银行账户；
- [ ] 银行账户户名与公司法定名称的对应关系；
- [ ] 银行账户归属证明；
- [ ] 银行出具的对账单、证明信或 Stripe 接受的同类文件；
- [ ] Stripe 要求时提供近期公司银行流水；
- [ ] Stripe 要求时提供财务报表、管理账目或现金余额证明；
- [ ] 新商户如果曾使用其他支付服务商，准备最近的处理记录；
- [ ] 历史退款率、拒付率和争议处理记录。

完整银行账号和银行流水不得放在网站上。

## 五、礼品卡受限业务的附加尽调资料

Stripe 不一定一次性要求全部材料，但礼品卡商户应在申请前准备完整证据链。

### 5.1 货源和授权

- [ ] 所有供应商的公司法定名称、注册国家和联系方式；
- [ ] 与供应商签署的有效合同；
- [ ] 近期采购订单；
- [ ] 近期采购发票；
- [ ] 向供应商付款的记录；
- [ ] 礼品卡供应 API 或后台合作证明；
- [ ] 供应商有权提供相应礼品卡的证明；
- [ ] 公司有权转售相应品牌礼品卡的授权链；
- [ ] 使用品牌名称、Logo和礼品卡图片的授权或合法依据；
- [ ] 库存、可用额度或实时供应能力证明；
- [ ] 不采购个人回收卡、异常来源卡或来历不明卡的内部政策。

### 5.2 业务模式和资金流

- [ ] 从客户付款到卡密交付的完整流程图或书面说明；
- [ ] Stripe 收款主体、网站经营主体和实际履约主体之间的关系；
- [ ] 客户付款后公司何时向供应商采购；
- [ ] 公司是否预先持有库存；
- [ ] 平均交付时间和最长交付时间；
- [ ] 平均客单价；
- [ ] 预计月交易笔数和交易金额；
- [ ] 主要客户国家或地区；
- [ ] 商品利润来源和定价方式；
- [ ] 退款资金由谁承担；
- [ ] 供应商无法履约时公司的备用方案；
- [ ] 是否存在其他商户、分销商或平台代收款；如有必须完整披露。

### 5.3 风控、履约和争议证明

- [ ] 单笔、每日和每月购买限额；
- [ ] 新客户和高金额订单的人工审核规则；
- [ ] IP、设备、邮箱、支付国家和兑换地区不一致时的处理规则；
- [ ] 盗刷和卡片测试防护措施；
- [ ] 高风险订单延迟交付或取消退款规则；
- [ ] 卡密生成、读取、交付和查看日志；
- [ ] 能将交付记录与具体订单、客户和付款对应；
- [ ] 客户收到卡密的邮件或账户记录；
- [ ] 无效码或已兑换码的供应商核验流程；
- [ ] 投诉、退款和拒付处理流程；
- [ ] 客服响应时效和升级机制；
- [ ] 确保库存覆盖预期销售量的措施。

## 六、Stripe Dashboard 中必须保持一致的信息

| Stripe 字段或配置 | 应对应的资料 |
| --- | --- |
| Legal business name | ACRA 法定公司名 |
| Business registration number | UEN |
| Business address | ACRA/经营地址及证明 |
| Business website | US Gift Card Hub 正式 HTTPS 域名 |
| DBA / business name | US Gift Card Hub |
| Product description | 第三方美国区数字礼品卡销售及交付模式 |
| Industry / MCC | 如实选择最接近礼品卡、储值产品或 Stripe 指定的类别 |
| Support email | 网站公开的公司客服邮箱 |
| Support phone | 网站公开的公司客服电话 |
| Support URL | 网站公开的 Contact Us 页面 |
| Statement descriptor | 客户能识别为 US Gift Card Hub 的账单名称 |
| Terms URL | 网站正式 Terms of Service |
| Privacy URL | 网站正式 Privacy Policy |
| Refund URL | 网站正式 Refund Policy |
| Bank account owner | 公司法定名称或 Stripe 明确认可的对应名称 |
| Account representative | ACRA 关键人员或持有效授权书的负责人 |
| Owners and directors | ACRA、股权证明和 Stripe 提交信息一致 |

## 七、提交前资料包

### A. 网站公开资料包

- [ ] 正式域名；
- [ ] 公司法定英文名；
- [ ] UEN；
- [ ] 公司公开地址；
- [ ] 品牌与公司关系声明；
- [ ] 客服邮箱、电话、即时联系渠道和客服时间；
- [ ] 真实商品、售价、USD币种、地区限制和交付时效；
- [ ] Terms of Service；
- [ ] Privacy Policy；
- [ ] Refund Policy；
- [ ] Digital Delivery Policy；
- [ ] Cancellation and Return Policy；
- [ ] Region/Legal Restrictions；
- [ ] 税费、发票和促销条件；
- [ ] 支付安全及接受的银行卡说明。

### B. Stripe 新加坡 KYC 私密资料包

- [ ] 最新 ACRA BizFile；
- [ ] 公司注册和地址证明；
- [ ] 全部董事资料；
- [ ] 最终受益人和完整股权结构；
- [ ] 账户负责人身份、地址和活体认证；
- [ ] 必要时的 Letter of Authorisation；
- [ ] 公司银行账户归属证明；
- [ ] 网站控制权证明。

### C. 礼品卡受限业务资料包

- [ ] 供应商名单和合同；
- [ ] 采购订单、发票和付款记录；
- [ ] 转售及品牌素材授权；
- [ ] 库存或供应 API 证明；
- [ ] 业务模式和资金流说明；
- [ ] 预计交易量和客单价；
- [ ] 风控、交付、退款和争议处理流程；
- [ ] 可核验的数字交付日志方案；
- [ ] 历史支付处理、退款和拒付资料（如有）；
- [ ] Stripe 额外要求的财务材料。

## 八、公司信息收集表

以下内容由公司负责人填写，用于制作公开政策和准备 Stripe 申报。敏感身份证件、银行流水和密钥不填写在本表中。

| 项目 | 公司填写 |
| --- | --- |
| 公司法定英文全名 |  |
| UEN |  |
| 公司法律实体类型 |  |
| 注册地址 |  |
| 实际经营地址（如不同） |  |
| 网站品牌名称 | US Gift Card Hub |
| 正式域名 |  |
| 客服邮箱 |  |
| 客服电话 |  |
| WhatsApp/在线客服 |  |
| 客服时间和时区 |  |
| 一般回复时效 |  |
| GST 注册状态及编号 |  |
| 主要销售国家/地区 |  |
| 供应商类型 |  |
| 是否有正式供应商合同 |  |
| 是否有采购发票 |  |
| 是否有转售授权 |  |
| 是否有品牌素材使用授权 |  |
| 礼品卡交付方式 |  |
| 正常交付时效 |  |
| 最长交付时效 |  |
| 允许退款的情况 |  |
| 不允许退款的情况 |  |
| 退款申请期限 |  |
| 退款审核时效 |  |
| 预计平均客单价 |  |
| 预计月交易笔数 |  |
| 预计月交易金额 |  |
| 单客户购买限额 |  |
| Stripe 账户负责人职务 |  |
| 是否为 ACRA 登记关键人员 |  |
| 是否已有新加坡公司银行账户 |  |

## 九、官方参考资料

- [Stripe Website Checklist](https://docs.stripe.com/get-started/checklist/website)
- [Stripe Prohibited and Restricted Businesses](https://stripe.com/legal/restricted-businesses)
- [Stripe Prohibited and Restricted Businesses FAQ](https://support.stripe.com/questions/prohibited-and-restricted-businesses-list-faqs)
- [Stripe Business Website for Account Activation FAQ](https://support.stripe.com/questions/business-website-for-account-activation-faq)
- [Stripe Business Information Requirements](https://support.stripe.com/questions/business-information-requirements-to-use-stripe)
- [Stripe Singapore 2025 Verification Requirements](https://support.stripe.com/questions/2025-updates-to-singapore-verification-requirements)
- [Stripe Singapore Private Company Requirements](https://support.stripe.com/questions/2025-updates-to-singapore-verification-requirements-private-companies?locale=en-GB)
- [Stripe Representative Authority Verification](https://support.stripe.com/questions/representative-authority-verification?locale=en-GB)
- [Stripe Singapore UBO and Director Requirements](https://support.stripe.com/questions/singapore-ultimate-beneficial-ownership-and-director-requirements?locale=en-GB)
- [Stripe URL and Business Verification Errors](https://docs.stripe.com/connect/handling-api-verification#url-verification)
- [Stripe Credit Account Review FAQ](https://support.stripe.com/questions/credit-account-review-process-frequently-asked-questions)

---

本清单用于准备 Stripe 审核，不构成 Stripe 的预批准，也不构成法律、税务或监管意见。Stripe 可能根据账户、业务模式、交易国家、货源和风险水平要求补充材料、设置准备金、限制能力或拒绝支持。最终要求以 Stripe Dashboard 中显示的待办事项及 Stripe 官方审核回复为准。
