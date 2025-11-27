create table grmgf.dim_company
(
    stock_name                varchar(20)    not null comment '股票代码，统一主键'
        primary key,
    sec_short_name            varchar(100)   null comment '股票简称',
    full_name_cn              varchar(255)   null comment '公司全称（中文）',
    full_name_en              varchar(255)   null comment '公司全称（英文）',
    industry_code             varchar(50)    null comment '行业代码（主口径）',
    industry_name             varchar(255)   null comment '行业名称（主口径）',
    credit_code               varchar(64)    null comment '统一社会信用代码',
    legal_representative      varchar(100)   null comment '法定代表人',
    company_status            varchar(50)    null comment '公司状态',
    registered_address        varchar(500)   null comment '注册地址',
    office_address            varchar(500)   null comment '办公地址',
    office_lng                decimal(12, 6) null comment '办公地点经度',
    office_lat                decimal(12, 6) null comment '办公地点纬度',
    market_type               varchar(50)    null comment '市场类型（主板/中小板/创业板等）',
    exchange_name             varchar(50)    null comment '交易所名称',
    first_listed_date         date           null comment '首次上市日期',
    list_year                 int            null,
    board_secretary           varchar(100)   null comment '董事会秘书',
    secretary_phone           varchar(50)    null comment '董秘联系电话',
    secretary_email           varchar(100)   null comment '董秘邮箱',
    securities_representative varchar(100)   null comment '证券事务代表',
    registered_capital        decimal(20, 2) null comment '注册资本',
    website                   varchar(255)   null comment '公司网站',
    business_scope            text           null,
    data_source               varchar(100)   null comment '数据来源',
    remark                    varchar(500)   null comment '备注'
)
    comment '上市公司维度表' charset = utf8mb4;

create table grmgf.dim_factory
(
    factory_uuid         char(36)       not null comment '工厂唯一标识，建议使用 UUID'
        primary key,
    stock_name           varchar(20)    null comment '关联上市公司股票代码，可为空',
    company_name         varchar(255)   null comment '工厂/企业名称',
    company_address      varchar(500)   null comment '工厂地址',
    city                 varchar(100)   null comment '城市',
    district             varchar(100)   null comment '区/县',
    credit_code          varchar(64)    null comment '统一社会信用代码',
    legal_representative varchar(100)   null comment '法定代表人',
    company_type         varchar(100)   null comment '公司类型',
    company_status       varchar(50)    null comment '企业状态',
    registered_capital   decimal(20, 2) null comment '注册资本',
    registration_date    date           null comment '成立日期',
    lon                  decimal(12, 6) null comment '经度',
    lat                  decimal(12, 6) null comment '纬度',
    former_names         varchar(500)   null comment '曾用名（如有）',
    data_source          varchar(100)   null comment '数据来源',
    remark               varchar(500)   null comment '备注'
)
    comment '工厂维度表' charset = utf8mb4;

create table grmgf.dim_pollution_enterprise
(
    stoke_name          varchar(255)         not null,
    year                int                  not null,
    pollution_discharge tinyint(1) default 0 null comment '0=否,1=是',
    primary key (stoke_name, year)
)
    comment '是否重点排污企业（按上市公司+年份）' charset = utf8mb4;

create table grmgf.fact_carbon_emission
(
    `index` int auto_increment
        primary key,
    name    varchar(255) null,
    year    int          not null,
    type    varchar(255) null,
    max     double       null,
    mean    float        null,
    min     double       null,
    sum     double       null
);

create table grmgf.fact_env_penalty_event
(
    stoke_name     varchar(255)   not null,
    year           int            not null,
    penalty_amount decimal(18, 2) not null,
    primary key (stoke_name, year)
)
    charset = utf8mb4;

create table grmgf.fact_env_subsidy_event
(
    `index`        bigint auto_increment
        primary key,
    stoke_name     varchar(255)                not null,
    statistic_date varchar(255)                null,
    item           varchar(255)                null,
    subsidy_amount decimal(18, 2) default 0.00 null
)
    comment '上市公司环境补助事实表' charset = utf8mb4;

create table grmgf.fact_esg_score_annual
(
    stock_name     text   null,
    year           bigint null,
    sec_short_name text   null,
    esg_score      double null,
    data_source    text   null
)
    charset = utf8mb4;

create table grmgf.fact_fin_panel_annual
(
    stock_name              varchar(10)                         not null comment '股票代码，由证券代码统一到stock_name',
    year                    int                                 not null comment '年份',
    sec_short_name          varchar(64)                         null comment '证券简称',
    industry_code_a         varchar(64)                         null comment '行业代码A',
    industry_name_a         varchar(128)                        null comment '行业名称A',
    company_full_name       varchar(255)                        null comment '公司全称',
    province_name           varchar(64)                         null comment '所属省份',
    province_code           varchar(16)                         null comment '所属省份代码',
    city_name               varchar(64)                         null comment '所属城市',
    city_code               varchar(16)                         null comment '所属城市代码',
    company_nature          varchar(64)                         null comment '上市公司经营性质',
    found_year              int                                 null comment '成立年份',
    list_year               int                                 null comment '上市年份',
    operating_revenue       decimal(20, 2)                      null comment '营业总收入',
    operating_cost          decimal(20, 2)                      null comment '营业总成本',
    selling_expense         decimal(20, 2)                      null comment '销售费用',
    admin_expense           decimal(20, 2)                      null comment '管理费用',
    rd_expense              decimal(20, 2)                      null comment '研发费用',
    finance_expense         decimal(20, 2)                      null comment '财务费用',
    total_profit            decimal(20, 2)                      null comment '利润总额',
    net_profit              decimal(20, 2)                      null comment '净利润',
    current_ratio           decimal(10, 4)                      null comment '流动比率',
    quick_ratio             decimal(10, 4)                      null comment '速动比率',
    cash_ratio              decimal(10, 4)                      null comment '现金比率',
    debt_asset_ratio        decimal(10, 4)                      null comment '资产负债率',
    current_assets_ratio    decimal(10, 4)                      null comment '流动资产比率',
    cash_assets_ratio       decimal(10, 4)                      null comment '现金资产比率',
    inventory_turnover_a    decimal(10, 4)                      null comment '存货周转率A',
    ap_turnover_a           decimal(10, 4)                      null comment '应付账款周转率A',
    total_assets_turnover_a decimal(10, 4)                      null comment '总资产周转率A',
    operating_profit_margin decimal(10, 4)                      null comment '营业利润率',
    selling_expense_ratio   decimal(10, 4)                      null comment '销售费用率',
    admin_expense_ratio     decimal(10, 4)                      null comment '管理费用率',
    finance_expense_ratio   decimal(10, 4)                      null comment '财务费用率',
    rd_expense_ratio        decimal(10, 4)                      null comment '研发费用率',
    net_profit_growth_a     decimal(10, 4)                      null comment '净利润增长率A',
    pe_1                    decimal(10, 4)                      null comment '市盈率(PE)1',
    ps_1                    decimal(10, 4)                      null comment '市销率(PS)1',
    pb                      decimal(10, 4)                      null comment '市净率(PB)',
    tobin_q_a               decimal(10, 4)                      null comment '托宾Q值A',
    z_score                 decimal(10, 4)                      null comment 'Z指数',
    herfindahl_3_index      decimal(10, 4)                      null comment 'Herfindahl_3指数',
    created_at              timestamp default CURRENT_TIMESTAMP not null comment '创建时间',
    updated_at              timestamp default CURRENT_TIMESTAMP not null on update CURRENT_TIMESTAMP comment '更新时间',
    primary key (stock_name, year)
)
    comment '简化版上市公司年度财务与指标面板表';

create index idx_industry_year
    on grmgf.fact_fin_panel_annual (industry_code_a, year);

create index idx_province_year
    on grmgf.fact_fin_panel_annual (province_code, year);

create table grmgf.fact_green_investment_annual
(
    stock_name              varchar(20)    not null comment '股票代码',
    year                    year           not null comment '年度',
    green_investment_amount decimal(20, 2) null comment '绿色投资总额',
    green_capex_ratio       decimal(10, 4) null comment '绿色投资占资本开支比重',
    investment_category     varchar(255)   null comment '绿色投资类别（节能减排/清洁能源等）',
    project_count           int            null comment '绿色项目数量（如有）',
    data_source             varchar(100)   null comment '数据来源：企业绿色投资.xlsx',
    remark                  varchar(500)   null comment '备注',
    primary key (stock_name, year),
    constraint fk_greeninv_company
        foreign key (stock_name) references grmgf.dim_company (stock_name)
)
    comment '企业绿色投资年度事实表' charset = utf8mb4;

create table grmgf.fact_green_patent_annual
(
    stock_name                   varchar(20)   not null comment '股票代码',
    year                         year          not null comment '年份',
    green_patent_invention_count int default 0 not null comment '发明型绿色专利数量',
    green_patent_utility_count   int default 0 not null comment '实用型绿色专利数量',
    green_patent_total_count     int           null comment '绿色专利总数 = 发明型 + 实用型',
    data_source_invention        varchar(100)  null comment '发明型绿色专利数据来源，如1990-2021发明型绿色专利.xlsx',
    data_source_utility          varchar(100)  null comment '实用型绿色专利数据来源，如1990-2021实用型绿色专利.xlsx',
    remark                       varchar(500)  null comment '备注',
    primary key (stock_name, year),
    constraint fk_green_patent_company
        foreign key (stock_name) references grmgf.dim_company (stock_name)
)
    comment '绿色专利年度事实表（发明型 + 实用型，综合版）' charset = utf8mb4;

create table grmgf.fact_patent_annual
(
    stock_name             varchar(20)  not null comment '股票代码',
    year                   year         not null comment '年份',
    patent_total_count     int          null comment '专利总数，对应Excel: 专利',
    patent_invention_count int          null comment '发明专利数量',
    patent_utility_count   int          null comment '实用新型数量',
    patent_design_count    int          null comment '外观设计数量',
    data_source            varchar(100) null comment '数据来源：2007_2024_Patent_Data.xlsx',
    remark                 varchar(500) null comment '备注',
    primary key (stock_name, year),
    constraint fk_patent_company
        foreign key (stock_name) references grmgf.dim_company (stock_name)
)
    comment '综合专利年度事实表（2007–2024）' charset = utf8mb4;

create table grmgf.fact_pollution_fee_annual
(
    stoke_name         varchar(255)                not null,
    year               int                         not null,
    item               varchar(255)                null,
    environment_amount decimal(18, 2) default 0.00 null,
    primary key (stoke_name, year)
)
    comment '上市公司年度污染/环保费用表' charset = utf8mb4;

