with accounts as (
    select *
    from {{ ref('stg_quickbooks__account') }}
),

classification_fix as (
    select 
        {{ dbt_utils.star(from=ref('stg_quickbooks__account'), except=["classification"]) }},
        case when classification is not null
            then classification
            when classification is null and account_type in ('Bank', 'Other Current Asset', 'Fixed Asset', 'Other Asset', 'Accounts Receivable')
                then 'Asset'
            when classification is null and account_type = 'Equity'
                then 'Equity'
            when classification is null and account_type in ('Expense', 'Other Expense', 'Cost of Goods Sold')
                then 'Expense'
            when classification is null and account_type in ('Accounts Payable', 'Credit Card', 'Long Term Liability', 'Other Current Liability')
                then 'Liability'
            when classification is null and account_type in ('Income', 'Other Income')
                then 'Revenue'
                    end as classification
    from accounts
),

classification_add as (
    select
        *,
        case when classification in ('Liability', 'Equity')
            then -1
        when classification = 'Asset'
            then 1
            else null
                end as multiplier,
        case when classification in ('Asset', 'Liability', 'Equity')
            then 'balance_sheet'
            else 'income_statement'
                end as financial_statement_helper,
        case when classification in ('Asset', 'Expense')
            then 'debit'
            else 'credit'
                end as transaction_type
    from classification_fix
),

final as (
    select 
        *,
        balance * multiplier as adjusted_balance
    from classification_add
)

select *
from final