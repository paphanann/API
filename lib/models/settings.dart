import '../core/json_util.dart';

class AppSettings {
  const AppSettings({
    required this.companyName,
    required this.taxId,
    required this.address,
    required this.erp,
    required this.endpoint,
    required this.autoSync,
    required this.notifyError,
    required this.notifySuccess,
    this.companyCode = '',
    this.phone = '',
    this.email = '',
    this.currency = 'THB - บาทไทย',
    this.timezone = 'Asia/Bangkok (UTC+7)',
    this.dateFormat = 'DD/MM/YYYY',
    this.numberFormat = '1,234.56',
    this.environment = 'Sandbox',
    this.database = '',
    this.username = '',
    this.createSalesOrder = true,
    this.createDelivery = true,
    this.createReturn = true,
    this.createCreditMemo = false,
    this.defaultCardCode = '',
    this.defaultWarehouse = '',
    this.defaultBranch = '',
    this.defaultTax = '',
    this.erpLastChecked,
    this.logo = '',
  });

  factory AppSettings.blank() => const AppSettings(
        companyName: '',
        taxId: '',
        address: '',
        erp: 'SAP Business One',
        endpoint: '',
        autoSync: true,
        notifyError: true,
        notifySuccess: false,
      );

  factory AppSettings.fromApi(Map<String, dynamic> m) {
    const erps = {'SAP S/4HANA', 'SAP Business One', 'SAP B1', 'Custom ERP'};
    var erp = pickStr(m, ['erp', 'Erp', 'ErpSystem'], or: 'SAP Business One');
    if (erp == 'SAP B1') erp = 'SAP Business One';
    if (!erps.contains(erp)) erp = 'SAP Business One';
    return AppSettings(
      companyName: pickStr(m, ['companyName', 'CompanyName', 'Name'], or: ''),
      companyCode: pickStr(m, ['companyCode', 'CompanyCode', 'Code'], or: ''),
      taxId: pickStr(m, ['taxId', 'TaxId'], or: ''),
      phone: pickStr(m, ['phone', 'Phone', 'Tel'], or: ''),
      address: pickStr(m, ['address', 'Address'], or: ''),
      email: pickStr(m, ['email', 'Email'], or: ''),
      currency: pickStr(m, ['currency', 'Currency'], or: 'THB - บาทไทย'),
      timezone: pickStr(m, ['timezone', 'Timezone', 'TimeZone'], or: 'Asia/Bangkok (UTC+7)'),
      dateFormat: pickStr(m, ['dateFormat', 'DateFormat'], or: 'DD/MM/YYYY'),
      numberFormat: pickStr(m, ['numberFormat', 'NumberFormat'], or: '1,234.56'),
      erp: erp,
      environment: pickStr(m, ['environment', 'Environment'], or: 'Sandbox'),
      endpoint: pickStr(m, ['endpoint', 'Endpoint'], or: ''),
      database: pickStr(m, ['database', 'Database', 'CompanyDatabase'], or: ''),
      username: pickStr(m, ['username', 'Username', 'ErpUser'], or: ''),
      autoSync: pick(m, ['autoSync', 'AutoSync']) == true,
      notifyError: pick(m, ['notifyError', 'NotifyError']) != false,
      notifySuccess: pick(m, ['notifySuccess', 'NotifySuccess']) == true,
      createSalesOrder: pickBool(m, ['createSalesOrder', 'CreateSalesOrder']) ?? true,
      createDelivery: pickBool(m, ['createDelivery', 'CreateDelivery']) ?? true,
      createReturn: pickBool(m, ['createReturn', 'CreateReturn']) ?? true,
      createCreditMemo: pickBool(m, ['createCreditMemo', 'CreateCreditMemo']) ?? false,
      defaultCardCode: pickStr(m, ['defaultCardCode', 'DefaultCardCode', 'CardCode'], or: ''),
      defaultWarehouse: pickStr(m, ['defaultWarehouse', 'DefaultWarehouse', 'WhsCode'], or: ''),
      defaultBranch: pickStr(m, ['defaultBranch', 'DefaultBranch', 'Branch'], or: ''),
      defaultTax: pickStr(m, ['defaultTax', 'DefaultTax', 'TaxCode'], or: ''),
      erpLastChecked: pickTime(m, ['erpLastChecked', 'ErpLastChecked', 'LastChecked']),
      logo: pickStr(m, ['logo', 'Logo', 'logoUrl', 'LogoUrl', 'companyLogo', 'CompanyLogo'], or: ''),
    );
  }

  final String companyName;
  final String companyCode;
  final String taxId;
  final String phone;
  final String address;
  final String email;
  final String currency;
  final String timezone;
  final String dateFormat;
  final String numberFormat;
  final String erp;
  final String environment;
  final String endpoint;
  final String database;
  final String username;
  final bool autoSync;
  final bool notifyError;
  final bool notifySuccess;
  final bool createSalesOrder;
  final bool createDelivery;
  final bool createReturn;
  final bool createCreditMemo;
  final String defaultCardCode;
  final String defaultWarehouse;
  final String defaultBranch;
  final String defaultTax;
  final DateTime? erpLastChecked;
  final String logo;

  Map<String, dynamic> toJson({String? password}) => {
        'companyName': companyName,
        'companyCode': companyCode,
        'taxId': taxId,
        'phone': phone,
        'address': address,
        'email': email,
        'currency': currency,
        'timezone': timezone,
        'dateFormat': dateFormat,
        'numberFormat': numberFormat,
        'erp': erp,
        'environment': environment,
        'endpoint': endpoint,
        'database': database,
        'username': username,
        if (password != null && password.isNotEmpty) 'password': password,
        'autoSync': autoSync,
        'notifyError': notifyError,
        'notifySuccess': notifySuccess,
        'createSalesOrder': createSalesOrder,
        'createDelivery': createDelivery,
        'createReturn': createReturn,
        'createCreditMemo': createCreditMemo,
        'defaultCardCode': defaultCardCode,
        'defaultWarehouse': defaultWarehouse,
        'defaultBranch': defaultBranch,
        'defaultTax': defaultTax,
        if (logo.isNotEmpty) 'logo': logo,
      };
}
