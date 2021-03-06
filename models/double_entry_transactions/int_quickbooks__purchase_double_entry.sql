/*
Table that creates a debit record to a specified expense account and a credit record to the payment account.
*/

--To disable this model, set the using_purchase variable within your dbt_project.yml file to False.
{{ config(enabled=var('using_purchase', True)) }}

with purchases as (
    select *
    from {{ref('stg_quickbooks__purchase')}}
),

purchase_lines as (
    select *
    from {{ref('stg_quickbooks__purchase_line')}}
),

items as (
    select *
    from {{ref('stg_quickbooks__item')}}
),

purchase_join as (
    select
        purchases.purchase_id as transaction_id,
        purchases.transaction_date,
        purchase_lines.amount,
        -- case when purchase_lines.account_expense_account_id is null and items.type = 'Inventory'
        --     then items.asset_account_id
        -- when purchase_lines.account_expense_account_id is null and items.type != 'Inventory'
        --     then coalesce(items.income_account_id, items.expense_account_id) --added asset to test
        --     else purchase_lines.account_expense_account_id
        --         end as payed_to_account_id,
        coalesce(purchase_lines.account_expense_account_id, items.expense_account_id) as payed_to_account_id,
        purchases.account_id as payed_from_account_id,
        case when coalesce(purchases.credit, false) = true then 'debit' else 'credit' end as payed_from_transaction_type,
        case when coalesce(purchases.credit, false) = true then 'credit' else 'debit' end as payed_to_transaction_type
    from purchases
    
    inner join purchase_lines
        on purchases.purchase_id = purchase_lines.purchase_id

    left join items
        on purchase_lines.item_expense_item_id = items.item_id
),

final as (
    select
        transaction_id,
        transaction_date,
        amount,
        payed_from_account_id as account_id,
        payed_from_transaction_type as transaction_type,
        'purchase' as transaction_source
    from purchase_join

    union all

    select
        transaction_id,
        transaction_date,
        amount,
        payed_to_account_id as account_id,
        payed_to_transaction_type as transaction_type,
        'purchase' as transaction_source
    from purchase_join
)

select *
from final