# End-to-End Customer Purchase Analytics

## Project Overview

This project analyzes customer purchasing behavior using Excel, MySQL, and Power BI. The objective is to transform raw transactional data into actionable business insights through customer segmentation, cohort analysis, customer lifetime value (CLV) analysis, and churn analytics.

The project follows a complete analytics workflow including data cleaning, SQL-based data modeling, business metric creation, and interactive dashboard development.

---

## Business Objectives

- Identify high-value customers and revenue-driving segments.
- Analyze customer retention trends over time.
- Measure Customer Lifetime Value (CLV).
- Detect churned, at-risk, and cooling customers.
- Support data-driven customer retention strategies.

---

## Tech Stack

- Microsoft Excel
- MySQL
- SQL Views
- Power BI
- DAX
- Data Modeling

---

## Repository Structure

```text
Data/
SQL/
PowerBI/
Screenshots/
```

### Data
Contains the original transactional dataset used for analysis.

### SQL
Contains SQL scripts for:
- Data cleaning
- Feature engineering
- Business views creation
- Analytical datasets

### PowerBI
Contains the final Power BI dashboard file.

### Screenshots
Contains dashboard screenshots for quick project review.

---

## Dashboard Pages

### 1. Executive Summary
Provides a high-level overview of:

- Total Customers
- Total Orders
- Total Revenue
- Average Order Value
- Revenue per Customer
- Repeat Purchase Rate

Includes:
- Revenue Trend Analysis
- Segment Distribution
- New vs Repeat Customer Analysis

---

### 2. Customer Segmentation (RFM Analysis)

Customers are segmented using:

- Recency
- Frequency
- Monetary Value

Segments include:

- VIP / Champions
- Loyal
- At-Risk
- Lost
- Hibernating
- New
- Others

Includes:

- RFM Scatter Analysis
- Revenue by Segment
- Customer Count by Segment

---

### 3. Cohort Retention Analysis

Analyzes customer retention over time using cohort analysis.

Includes:

- Monthly Retention Heatmap
- Average M1 Retention
- Average M3 Retention
- Average M6 Retention

Key Insight:
Tracks how customer retention changes after acquisition.

---

### 4. Customer Lifetime Value (CLV)

Evaluates long-term customer value.

KPIs:

- Average CLV
- Median CLV
- VIP Average Order Value
- Top 10% Revenue Share

Includes:

- CLV Distribution
- First Order Value vs Lifetime Value Analysis
- Customer-Level CLV Table

---

### 5. Churn & At-Risk Analysis

Identifies customers likely to stop purchasing.

KPIs:

- Active Customers
- At-Risk Customers
- Cooling Customers
- Churned Customers
- Active Revenue
- At-Risk Revenue
- Cooling Revenue
- Churned Revenue

Includes:

- Recency Distribution
- Revenue by Churn Category
- Customer-Level Churn Analysis

---

## Key Insights

- VIP customers contribute a significant share of total revenue.
- Customer retention declines progressively across cohort months.
- A small percentage of customers drive a large portion of revenue.
- Churned and at-risk customers represent substantial revenue recovery opportunities.
- Customer Lifetime Value varies significantly across segments.

---

## Project Workflow

1. Data Collection
2. Data Cleaning in Excel
3. SQL Data Transformation
4. SQL View Creation
5. Data Modeling
6. DAX Measures Development
7. Dashboard Design in Power BI
8. Business Insights Generation
