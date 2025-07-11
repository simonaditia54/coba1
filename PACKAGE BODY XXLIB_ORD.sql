PACKAGE BODY XXLIB_ORD
IS
  G_HNA     QP_SECU_LIST_HEADERS_V.NAME%TYPE DEFAULT '55S';
  G_NRDP    VARCHAR2( 16 ) DEFAULT '55N';
  G_DB_NAME V$DATABASE.NAME%TYPE DEFAULT NULL;
  E_BOHONG  EXCEPTION;

  ----------------------------------------------------
  PROCEDURE PRINT_SO( EVENT VARCHAR2 )
  IS
    P1                 VARCHAR2( 150 ) DEFAULT NULL;
    P6                 VARCHAR2( 150 ) DEFAULT NULL;
    P11                VARCHAR2( 150 ) DEFAULT NULL;
    P2                 VARCHAR2( 150 ) DEFAULT NULL;
    P7                 VARCHAR2( 150 ) DEFAULT NULL;
    P12                VARCHAR2( 150 ) DEFAULT NULL;
    P3                 VARCHAR2( 150 ) DEFAULT NULL;
    P8                 VARCHAR2( 150 ) DEFAULT NULL;
    P13                VARCHAR2( 150 ) DEFAULT NULL;
    P4                 VARCHAR2( 150 ) DEFAULT NULL;
    P9                 VARCHAR2( 150 ) DEFAULT NULL;
    P14                VARCHAR2( 150 ) DEFAULT NULL;
    P5                 VARCHAR2( 150 ) DEFAULT NULL;
    P10                VARCHAR2( 150 ) DEFAULT NULL;
    P15                VARCHAR2( 150 ) DEFAULT NULL;
    P_SET_PRINT_RESULT BOOLEAN DEFAULT NULL;
    V_ORDER_NUMBER     VARCHAR2( 30 ) := NAME_IN( 'order.order_number' );
    FORM_NAME          VARCHAR2( 30 ) := NAME_IN( 'system.current_form' );
    P_REQID            PLS_INTEGER;
    OU_ID              PLS_INTEGER DEFAULT FND_PROFILE.VALUE( 'ORG_ID' );
    V_HEADER_ID        PLS_INTEGER DEFAULT NAME_IN( 'ORDER.header_id' );
    V_COUNT            PLS_INTEGER DEFAULT NULL;
    V_RUNNING_PRINT    DATE DEFAULT SYSDATE;
    V_RUNNING_BOOK     DATE DEFAULT SYSDATE + 1 / (24 * 60 * 6);
    V_RUNNING_TIME     DATE;
    -- for print piutang overdue ----
    V_FORM_STATUS      VARCHAR2( 30 ) := NAME_IN( 'system.form_status' );
    V_CUST_NO          VARCHAR2( 50 ) := NAME_IN( 'order.customer_number' );
    V_CUST_NAME        VARCHAR2( 150 ) := NAME_IN( 'order.sold_to' );
    V_CCY              VARCHAR2( 10 ) := NAME_IN( 'order.transactional_curr_code' );
    V_OU_ID            PLS_INTEGER := FND_PROFILE.VALUE( 'ORG_ID' );
    V_USERNAME         VARCHAR2( 50 ) := FND_PROFILE.VALUE( 'USERNAME' );
    V_MSG_LEVEL        PLS_INTEGER := NAME_IN( 'system.message_level' );
    V_CHECK            DATE;
    V_CHECK2           PLS_INTEGER;

    V_COUNT_SO         NUMBER;
    V_FLAG_PRN_PO      VARCHAR2( 1 );
    V_SOLD_TO_ORG_ID   NUMBER := NAME_IN( 'order.sold_to_org_id' );
  -- end print piutang overdue -----
  BEGIN
    IF FORM_NAME IN ('OEXOETEL', 'OEXOEORD')
    THEN
      -- for print piutang overdue ----
      IF EVENT = 'PIUTANG-OVERDUE'
      THEN
        V_COUNT_SO := 0;

        BEGIN
          --- index range, cost = 4
          SELECT SUBSTR( ATTRIBUTE1, 1, 1 )
            INTO V_FLAG_PRN_PO
            FROM RA_CUSTOMERS
           WHERE CUSTOMER_ID = V_SOLD_TO_ORG_ID;

          IF NVL( V_FLAG_PRN_PO, 'N' ) = 'Y'
          THEN
            /*
                           --index range, cost = 54
                           select count(1) into v_count_so
                           from oe_order_headers_all
                            where sold_to_org_id = v_sold_to_org_id
                             and trunc(ordered_date) = trunc(sysdate)
                            and org_id = v_ou_id ;
            */
            --index range, cost = 57
            SELECT COUNT( 1 )
              INTO V_COUNT_SO
              FROM OE_ORDER_HEADERS_ALL OEH, OE_ORDER_HOLDS_ALL OHOLD
             WHERE OEH.SOLD_TO_ORG_ID = V_SOLD_TO_ORG_ID
               AND TRUNC( OEH.ORDERED_DATE ) = TRUNC( SYSDATE )
               AND OEH.ORG_ID = V_OU_ID
               AND OHOLD.HEADER_ID = OEH.HEADER_ID
               AND OHOLD.ORG_ID = OEH.ORG_ID;
          END IF;
        EXCEPTION
          WHEN OTHERS
          THEN
            V_COUNT_SO := 0;
        END;

        --- kondisi v_count_so
        IF V_COUNT_SO = 1
        THEN
          BEGIN
            SELECT MAX( OHR.CREATION_DATE )
              INTO V_CHECK
              FROM OE_HOLD_RELEASES OHR, OE_ORDER_HOLDS_ALL OHOLD
             WHERE OHOLD.HOLD_RELEASE_ID = OHR.HOLD_RELEASE_ID
               AND OHOLD.HOLD_SOURCE_ID = OHR.HOLD_SOURCE_ID
               AND OHOLD.HEADER_ID = V_HEADER_ID
               AND OHOLD.ORG_ID = V_OU_ID;
          EXCEPTION
            WHEN OTHERS
            THEN
              V_CHECK := NULL;
          END;

          BEGIN
            SELECT COUNT( 1 )
              INTO V_CHECK2
              FROM OE_ORDER_HOLDS_ALL OHOLD
             WHERE OHOLD.HEADER_ID = V_HEADER_ID
               AND OHOLD.ORG_ID = V_OU_ID;
          EXCEPTION
            WHEN OTHERS
            THEN
              V_CHECK2 := 0;
          END;

          IF V_CHECK IS NULL
         AND V_CHECK2 <> 0
          THEN
            BEGIN
              IF V_FORM_STATUS <> 'QUERY'
              THEN
                XXLIB_GEN.SHOW_MSG( 'Save changes before print Piutang Overdue report' );
                RAISE E_BOHONG;
              END IF;

              P_SET_PRINT_RESULT := FND_REQUEST.SET_PRINT_OPTIONS( FND_PROFILE.VALUE( 'Printer' )
                                                                 , NULL
                                                                 , 1
                                                                 , TRUE
                                                                 , 'N' );

              IF P_SET_PRINT_RESULT = TRUE
              THEN
                IF V_CUST_NO IS NULL
                OR V_CUST_NAME IS NULL
                OR V_CCY IS NULL
                THEN
                  XXLIB_GEN.SHOW_MSG( 'Select valid order before print Piutang Overdue report' );
                  RAISE E_BOHONG;
                END IF;

                P_REQID := FND_REQUEST.SUBMIT_REQUEST( 'XXEPM'
                                                     , --'AR', /* MII: RENAME AR.EPM-S-LAPPIUOD >> XXEPM.EPM_AR_LPO */
                                                       'EPM_AR_LPO'
                                                     , --'EPM-S-LAPPIUOD', /* MII: AR.RENAME EPM-S-LAPPIUOD >> XXEPM.sEPM_AR_LPO */
                                                       'Piutang Overdue ' || V_CUST_NAME
                                                     , SYSDATE
                                                     , FALSE
                                                     , V_OU_ID
                                                     , V_CUST_NO
                                                     , V_CUST_NO
                                                     , V_CCY
                                                     , V_USERNAME
                                                     , V_ORDER_NUMBER
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , ''
                                                     , '' );

                /*
                 show_msg(
                        'v_cust_no   '|| v_cust_no    ||' '||
                        'v_cust_name '|| v_cust_name  ||chr(10)||
                        'v_ccy       '|| v_ccy        ||' '||
                        'v_ou_id     '|| v_ou_id      ||chr(10)||
                        'v_username  '|| v_username   ||' '||
                        'v_reqID     '|| v_reqID);
                 */
                IF P_REQID <> 0
                THEN
                  COPY( 20, 'system.message_level' );
                  COMMIT_FORM;
                  COPY( V_MSG_LEVEL, 'system.message_level' );
                  XXLIB_GEN.SHOW_MSG( 'Piutang Overdue ' || V_CUST_NAME || ' submitted with request id ' || P_REQID );
                ELSE
                  XXLIB_GEN.SHOW_MSG( 'Fail in Piutang Overdue Report submission', 'ERROR' );
                END IF;
              ELSE
                XXLIB_GEN.SHOW_MSG( 'Fail in printer identification', 'ERROR' );
              END IF;
            EXCEPTION
              WHEN E_BOHONG
              THEN
                NULL;
              WHEN OTHERS
              THEN
                COPY( V_MSG_LEVEL, 'system.message_level' );
                RAISE;
            END;
          END IF;
        END IF;
      --- kondisi v_count_so
      -- end print piutang overdue ----
      ELSE
        SELECT COUNT( * )
          INTO V_COUNT
          FROM OE_ORDER_HEADERS_ALL
         WHERE HEADER_ID = V_HEADER_ID
           AND BOOKED_FLAG = 'Y';

        IF EVENT = 'BOOK-ORDER'
        THEN
          V_RUNNING_TIME := V_RUNNING_BOOK;
        ELSE
          V_RUNNING_TIME := V_RUNNING_PRINT;
        END IF;

        IF V_COUNT > 0
       AND EVENT <> 'BOOK-ORDER'
        THEN
          P_SET_PRINT_RESULT := FND_REQUEST.SET_PRINT_OPTIONS( FND_PROFILE.VALUE( 'Printer' )
                                                             , NULL
                                                             , 1
                                                             , TRUE
                                                             , 'N' );

          IF P_SET_PRINT_RESULT = TRUE
          THEN
            P_REQID := FND_REQUEST.SUBMIT_REQUEST( 'XXEPM'
                                                 , --'ONT', /* MII: RENAME ONT.EPM-S-SO >> XXEPM.EPM_OM_SO */
                                                   'EPM_OM_SO'
                                                 , --'EPM-S-SO', /* MII: RENAME ONT.EPM-S-SO >> XXEPM.EPM_OM_SO */
                                                   'Sales Order ' || V_ORDER_NUMBER
                                                 , V_RUNNING_TIME
                                                 , FALSE
                                                 , OU_ID
                                                 , TO_NUMBER( V_ORDER_NUMBER )
                                                 , TO_NUMBER( V_ORDER_NUMBER )
                                                 , P4
                                                 , P5
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , ''
                                                 , '' );

            IF P_REQID <> 0
            THEN
              COMMIT_FORM;
              XXLIB_GEN.SHOW_MSG( 'Sales Order Report submitted with request id ' || P_REQID );
            ELSE
              XXLIB_GEN.SHOW_MSG( 'Fail in Sales Order Report submission', 'ERROR' );
            END IF;
          ELSE
            XXLIB_GEN.SHOW_MSG( 'Fail in printer identification', 'ERROR' );
            P_REQID := 0;
          END IF;
        END IF;
      END IF;
    END IF;
  EXCEPTION
    WHEN OTHERS
    THEN
      XXLIB_GEN.SHOW_MSG( 'Fail when printing on ' || FND_PROFILE.VALUE( 'Printer' ), 'ERROR' );
      RAISE FORM_TRIGGER_FAILURE;
  END;

  --------------------------------------------------------------------
  PROCEDURE VALIDATEPRL( EVENT VARCHAR2 )
  IS
    V_COUNT             PLS_INTEGER;
    V_PRINCIPAL         MTL_ITEM_CATEGORIES_V.SEGMENT5%TYPE;
    V_DIREKTORAT        MTL_ITEM_CATEGORIES_V.SEGMENT6%TYPE;
    V_LIST_HEADER_ID    EPM_KODE_SALUR.LIST_HEADER_ID%TYPE;

    FORM_NAME           VARCHAR2( 30 ) := NAME_IN( 'system.current_form' );
    PARAM_TO_PASS1      PLS_INTEGER := NAME_IN( 'line.inventory_item_id' );
    PARAM_TO_PASS2      PLS_INTEGER := NAME_IN( 'order.salesrep_id' );
    V_LOCATION_CUST_ID  VARCHAR2( 255 ) := NAME_IN( 'order.INVOICE_TO_ORG_ID' );
    V_HDR_PRICE_LIST    VARCHAR2( 16 ) := NAME_IN( 'order.PRICE_LIST' );
    V_HDR_PRICE_LIST_ID VARCHAR2( 16 ) := NAME_IN( 'order.PRICE_LIST_ID' );

    V_CURRENT_PRL       VARCHAR2( 16 ) := NAME_IN( 'line.Price_List' );
    V_CURRENT_PRL_ID    VARCHAR2( 16 ) := NAME_IN( 'line.Price_List_ID' );

    V_N_ORG_ID          PLS_INTEGER := NAME_IN( 'ORDER.ORG_ID' );

    V_PRICE_LIST        VARCHAR2( 255 );
    V_PRICE_LIST_ID     VARCHAR2( 255 );

    V_PZ_CODE           VARCHAR2( 2 );

    V_DIREKTORAT2       VARCHAR2( 30 );
    V_SALESREP_ID       VARCHAR2( 30 ) := NAME_IN( 'order.SALESREP_ID' );
  BEGIN
    IF FORM_NAME IN ('OEXOETEL', 'OEXOEORD')
    THEN
      --xxlib_gen.SHOW_MSG('masuk1');
      IF V_CURRENT_PRL IS NOT NULL
     AND PARAM_TO_PASS1 IS NOT NULL
      THEN
        --xxlib_gen.SHOW_MSG('masuk2');

        SELECT DISTINCT LTRIM( RTRIM( CAT.SEGMENT5 ) )
          --,
          --ltrim(rtrim( CAT.segment6 ))
          INTO V_PRINCIPAL
          --,
          --v_direktorat /ditutup per feb 16 by hengki
          FROM MTL_SYSTEM_ITEMS_B MST, MTL_ITEM_CATEGORIES_V CAT
         WHERE CAT.ORGANIZATION_ID = MST.ORGANIZATION_ID
           AND CAT.INVENTORY_ITEM_ID = MST.INVENTORY_ITEM_ID
           AND MST.INVENTORY_ITEM_ID = PARAM_TO_PASS1
           AND UPPER( CAT.CATEGORY_SET_NAME ) = 'INVENTORY'
           AND MST.ORGANIZATION_ID = V_N_ORG_ID;

        -- per feb 16 by hengki
        SELECT SEGMENT3
          INTO V_DIREKTORAT
          FROM EPM_SALES_DEPT_NEW_V
         WHERE SALESREP_ID = PARAM_TO_PASS2
           AND ORG_ID = V_N_ORG_ID;

        SELECT COUNT( * )
          INTO V_COUNT
          FROM EPM_KODE_SALUR
         WHERE SITE_USE_ID = V_LOCATION_CUST_ID
           AND RTRIM( LTRIM( DIREKTORAT ) ) = V_DIREKTORAT
           AND RTRIM( LTRIM( PRINCIPAL ) ) = V_PRINCIPAL;

        IF NVL( V_COUNT, 0 ) > 0
        THEN
          SELECT LIST_HEADER_ID
            INTO V_LIST_HEADER_ID
            FROM EPM_KODE_SALUR
           WHERE SITE_USE_ID = V_LOCATION_CUST_ID
             AND RTRIM( LTRIM( DIREKTORAT ) ) = V_DIREKTORAT
             AND RTRIM( LTRIM( PRINCIPAL ) ) = V_PRINCIPAL;

          SELECT NAME, LIST_HEADER_ID
            INTO V_PRICE_LIST, V_PRICE_LIST_ID
            FROM QP_SECU_LIST_HEADERS_V
           WHERE LIST_HEADER_ID = V_LIST_HEADER_ID;

          /* Start Pricing Zone */
          IF SUBSTR( V_PRICE_LIST, 1, 1 ) = SUBSTR( V_PRICE_LIST, 3, 1 )
         AND NVL( V_PRINCIPAL, '~' ) <> 'NRDP'
          THEN
            BEGIN
              SELECT PZ_CODE
                INTO V_PZ_CODE
                FROM XXEPM.EPM_PZ_MATRIX
               WHERE ORG_ID = V_N_ORG_ID
                 AND INVENTORY_ITEM_ID = PARAM_TO_PASS1;
            EXCEPTION
              WHEN OTHERS
              THEN
                V_PZ_CODE := '';
            END;

            IF V_PZ_CODE IS NOT NULL
            THEN
              V_PRICE_LIST := SUBSTR( V_PRICE_LIST, 1, 2 ) || V_PZ_CODE;
            END IF;
          END IF;

          /* End Pricing zone */

          BEGIN
            SELECT SEGMENT3
              INTO V_DIREKTORAT2
              FROM RA_SALESREPS_ALL RSA, GL_CODE_COMBINATIONS GCC
             WHERE 1 = 1
               AND RSA.GL_ID_REV = GCC.CODE_COMBINATION_ID
               AND RSA.SALESREP_ID = V_SALESREP_ID;
          END;

          /*
          if v_price_list <> v_current_prl then
             xxlib_gen.SHOW_MSG('Your price list not match with Kode Salur');
             raise form_trigger_failure;
          end if;
          */
          --penambahan logic untuk pharmamed bisa mengganti kode salur ke 555. ARIE 4-AUG-2016
          IF V_DIREKTORAT2 <> '1111'
          THEN
            IF V_PRICE_LIST <> V_CURRENT_PRL
            THEN
              XXLIB_GEN.SHOW_MSG( 'Your price list not match with Kode Salur1' );
              RAISE FORM_TRIGGER_FAILURE;
            END IF;
          END IF;

          IF V_DIREKTORAT2 = '1111'
         AND V_CURRENT_PRL NOT IN ('111'
                                 , '222'
                                 , '333'
                                 , '444'
                                 , '445'
                                 , '447'
                                 , '555'
                                 , '666'
                                 , '777'
                                 , '999'
                                 , V_PRICE_LIST)
          THEN
            XXLIB_GEN.SHOW_MSG( 'Your price list not match with Kode Salur2' );
            RAISE FORM_TRIGGER_FAILURE;
          END IF;
        --penambahan logic untuk pharmamed bisa mengganti kode salur ke 555. ARIE 4-AUG-2016
        ELSE
          NULL;
        --xxlib_gen.SHOW_MSG('masuk3');
        /*
        if v_hdr_price_list <> v_current_prl then
           xxlib_gen.SHOW_MSG('Your price list not match with Header1');
           raise form_trigger_failure;
        end if;*/
        END IF; --END IF XX_KODE_SALUR EXISTS
      ELSIF V_CURRENT_PRL IS NOT NULL
        AND PARAM_TO_PASS1 IS NULL
      THEN
        IF V_HDR_PRICE_LIST <> V_CURRENT_PRL
        THEN
          XXLIB_GEN.SHOW_MSG( 'Your price list not match with Header2' );
          RAISE FORM_TRIGGER_FAILURE;
        END IF;
      END IF;
    END IF;
  END;

  --------------------------------------------------------------------
  PROCEDURE CHECKNPWP( EVENT VARCHAR2 )
  IS
    V_ORDER_TYPE_ID       PLS_INTEGER;
    V_LOCATION_CUST_ID    PLS_INTEGER;
    V_LOCATION_SHIP_ID    PLS_INTEGER;
    V_FTZ                 VARCHAR2( 5 );
    V_TAX_REFERENCE       HZ_CUST_SITE_USES_ALL.TAX_REFERENCE%TYPE;
    V_ORDER_CATEGORY_CODE OE_TRANSACTION_TYPES.ORDER_CATEGORY_CODE%TYPE;
    V_TAX_AMOUNT          OE_ORDER_LINES_ALL.TAX_VALUE%TYPE;
    V_LINE_NO             OE_ORDER_LINES_ALL.LINE_NUMBER%TYPE;
    V_ITEM                OE_ORDER_LINES_ALL.INVENTORY_ITEM_ID%TYPE;
    FORM_NAME             VARCHAR2( 30 ) := NAME_IN( 'system.current_form' );
    LINE_NO               VARCHAR2( 30 );
    LINE_TAX_CODE         VARCHAR2( 20 );
    INTERNAL_TAX_CODE     VARCHAR2( 20 ) := 'Internal PPN';
    V_NUM_RECORD          PLS_INTEGER;
    V_ALERT_RESULT        PLS_INTEGER;
    V_MSG_LEVEL           PLS_INTEGER DEFAULT NAME_IN( 'system.message_level' );
    V_HEADER_ID           PLS_INTEGER DEFAULT NAME_IN( 'order.header_ID' );
    V_TAX_CODE            VARCHAR2( 100 );
    V_TAX_REFERENCE_LONG  PLS_INTEGER;
    OUID                  PLS_INTEGER DEFAULT FND_PROFILE.VALUE( 'ORG_ID' );
    V_TAX_REF_0           HZ_CUST_SITE_USES_ALL.TAX_REFERENCE%TYPE; --kristina 10mei2016 utk npwp 000000000000000
        BEGIN
    IF FORM_NAME IN ('OEXOETEL', 'OEXOEORD')
    THEN
      V_ORDER_TYPE_ID := NAME_IN( 'order.order_type_id' );

      IF V_ORDER_TYPE_ID IS NOT NULL
      THEN
        SELECT UPPER( ORDER_CATEGORY_CODE )
          INTO V_ORDER_CATEGORY_CODE
          FROM OE_TRANSACTION_TYPES_ALL --for r12 lse
         WHERE TRANSACTION_TYPE_ID = V_ORDER_TYPE_ID;

        IF V_ORDER_CATEGORY_CODE = 'RETURN'
        THEN
          V_LOCATION_CUST_ID := NAME_IN( 'order.INVOICE_TO_ORG_ID' );

          SELECT TAX_REFERENCE
            INTO V_TAX_REFERENCE
            FROM HZ_CUST_SITE_USES_ALL
           WHERE SITE_USE_ID = V_LOCATION_CUST_ID;

          ---- --kristina 10mei2016 utk npwp 000000000000000
          IF V_TAX_REFERENCE IS NOT NULL
          THEN
            V_TAX_REF_0 := RTRIM( REPLACE( V_TAX_REFERENCE, '.', '' ) );
            V_TAX_REF_0 := RTRIM( REPLACE( V_TAX_REF_0, '-', '' ) );
            V_TAX_REF_0 := RTRIM( REPLACE( V_TAX_REF_0, ',', '' ) );

            IF V_TAX_REF_0 = '0'
            OR V_TAX_REF_0 = '000'
            OR (SUBSTR( V_TAX_REF_0, 1, 5 ) = '00000'
            AND LENGTH( V_TAX_REF_0 ) < 15)
            THEN
              V_TAX_REFERENCE := NULL;
            END IF;
          END IF;

          ---- --kristina 10mei2016 utk npwp 000000000000000

          IF V_TAX_REFERENCE IS NULL
          THEN
            V_ITEM := NAME_IN( 'LINE.INVENTORY_ITEM_ID' );

            IF EVENT = 'PRE-BLOCK'
           AND V_ITEM IS NULL
            THEN
              XXLIB_GEN.SHOW_MSG( 'Customer ini tidak mempunyai  NPWP' );
            ELSIF EVENT IN ('BOOK')
            THEN
              V_TAX_AMOUNT := NAME_IN( 'ORDER.TAX' );
              V_TAX_AMOUNT := NVL( V_TAX_AMOUNT, 0 );

              IF V_TAX_AMOUNT <> 0
              THEN
                XXLIB_GEN.SHOW_MSG( 'Customer ini tidak mempunyai NPWP' || CHR( 10 ) || 'Besar pajak order tidak boleh lebih besar dari 0', 'ERROR' );
                RAISE FORM_TRIGGER_FAILURE;
              END IF;
            ELSIF EVENT IN ('AFTER-LINE')
            THEN
              -- v_lov_char_param1  := trunc(to_date(name_in('parameter.lov_char_param1'),'DD-MON-RRRR HH24:MI:SS'));

              -- v_tax_Code         := name_in('line.tax_code');
              BEGIN
                /* FOR R12 TAX LSE
                select v.tax_code into v_tax_Code
            from ar_vat_tax v, ar_system_parameters p
            where v.set_of_books_id=p.set_of_books_id
            and nvl(v.enabled_flag,'Y')='Y'
            and nvl(v.tax_class,'O')='O'
            and nvl(v.displayed_flag,'Y')='Y'
           -- and nvl(trunc(to_date(:parameter.lov_char_param1,'DD-MON-RRRR HH24:MI:SS')),trunc(sysdate)) between nvl(trunc(start_date),nvl(trunc(to_date(:parameter.lov_char_param1,'DD-MON-RRRR HH24:MI:SS')),trunc(sysdate)) ) and nvl(trunc(end_date),nvl(trunc(to_date(:parameter.lov_char_param1,'DD-MON-RRRR HH24:MI:SS')),trunc(sysdate)))
           -- and v.tax_code = :line.tax_Code ;
                 and v.tax_rate = 0;
                 */
                SELECT TAX_RATE_CODE
                  INTO V_TAX_CODE
                  FROM (SELECT DECODE( CREATED_BY, -1087, NVL( SUBSTRB( TAG, 1, 50 ), LOOKUP_CODE ), LOOKUP_CODE ) LOOKUP_CODE
                             , ENABLED_FLAG
                             , START_DATE_ACTIVE
                             , END_DATE_ACTIVE
                             , LOOKUP_TYPE
                             , LEAF_NODE
                          FROM FND_LOOKUP_VALUES
                         WHERE LANGUAGE = USERENV( 'LANG' )
                           AND LOOKUP_TYPE = 'ZX_OUTPUT_CLASSIFICATIONS'
                           AND SECURITY_GROUP_ID = 0
                           AND VIEW_APPLICATION_ID = 0) LKP
                     , ZX_ID_TCC_MAPPING_ALL TCC
                     , ZX_RATES_VL RVL
                 WHERE TCC.TAX_CLASSIFICATION_CODE = LKP.LOOKUP_CODE
                   AND TCC.TAX_RATE_CODE_ID = RVL.TAX_RATE_ID(+)
                   AND TCC.ACTIVE_FLAG = 'Y'
                   AND (TCC.TAX_CLASS = 'OUTPUT'
                     OR TCC.TAX_CLASS IS NULL)
                   AND TCC.ORG_ID = OUID
                   AND SYSDATE BETWEEN START_DATE_ACTIVE AND NVL( END_DATE_ACTIVE, SYSDATE )
                   AND RVL.PERCENTAGE_RATE = 0;
              EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                  V_TAX_CODE := '';
              END;

              COPY( V_TAX_CODE, 'line.tax_code' );
            END IF;
          END IF;

          SELECT LENGTH(
                   REPLACE(
                     REPLACE( REPLACE( REPLACE( REPLACE( REPLACE( UPPER( TAX_REFERENCE ), '.', '' ), '-', '' ), ' ', '' ), ',', '' ), '''', '' )
                   , '/'
                   , '' ) )
            INTO V_TAX_REFERENCE_LONG
            FROM HZ_CUST_SITE_USES_ALL
           WHERE SITE_USE_ID = V_LOCATION_CUST_ID;  
           
           XXLIB_GEN.SHOW_MSG( 'nama EVENT:' );         
           XXLIB_GEN.SHOW_MSG( EVENT );         

          IF V_TAX_REFERENCE_LONG <> 16
          OR ((INSTR( UPPER( V_TAX_REFERENCE ), 'A' )
               + INSTR( UPPER( V_TAX_REFERENCE ), 'B' )
               + INSTR( UPPER( V_TAX_REFERENCE ), 'C' )
               + INSTR( UPPER( V_TAX_REFERENCE ), 'D' )
               + INSTR( UPPER( V_TAX_REFERENCE ), 'E' )
               + INSTR( UPPER( V_TAX_REFERENCE ), 'F' )
               + INSTR( UPPER( V_TAX_REFERENCE ), 'G' )
               + INSTR( UPPER( V_TAX_REFERENCE ), 'H' )
               + INSTR( UPPER( V_TAX_REFERENCE ), 'I' )
               + INSTR( UPPER( V_TAX_REFERENCE ), 'J' )
               + INSTR( UPPER( V_TAX_REFERENCE ), 'K' )
               + INSTR( UPPER( V_TAX_REFERENCE ), 'L' )
               + INSTR( UPPER( V_TAX_REFERENCE ), 'M' )
               + INSTR( UPPER( V_TAX_REFERENCE ), 'N' )
               + INSTR( UPPER( V_TAX_REFERENCE ), 'O' )
               + INSTR( UPPER( V_TAX_REFERENCE ), 'P' )
               + INSTR( UPPER( V_TAX_REFERENCE ), 'Q' )
               + INSTR( UPPER( V_TAX_REFERENCE ), 'R' )
               + INSTR( UPPER( V_TAX_REFERENCE ), 'S' )
               + INSTR( UPPER( V_TAX_REFERENCE ), 'T' )
               + INSTR( UPPER( V_TAX_REFERENCE ), 'U' )
               + INSTR( UPPER( V_TAX_REFERENCE ), 'V' )
               + INSTR( UPPER( V_TAX_REFERENCE ), 'W' )
               + INSTR( UPPER( V_TAX_REFERENCE ), 'X' )
               + INSTR( UPPER( V_TAX_REFERENCE ), 'Y' )
               + INSTR( UPPER( V_TAX_REFERENCE ), 'Z' )) <>
              0)
          THEN
            V_ITEM := NAME_IN( 'LINE.INVENTORY_ITEM_ID' );   
            
            XXLIB_GEN.SHOW_MSG( 'V_ITEM: ' );                             
            XXLIB_GEN.SHOW_MSG( V_ITEM );

            IF EVENT = 'PRE-BLOCK'
           AND V_ITEM IS NULL
            THEN
              XXLIB_GEN.SHOW_MSG( 'Customer ini no NPWP nya kurang dari 16 / Tidak valid' );
            ELSIF EVENT IN ('AFTER-LINE')
            THEN
              BEGIN
                /* FOR R12 TAX LSE
             select v.tax_code into v_tax_Code
         from ar_vat_tax v, ar_system_parameters p
         where v.set_of_books_id=p.set_of_books_id
         and nvl(v.enabled_flag,'Y')='Y'
         and nvl(v.tax_class,'O')='O'
         and nvl(v.displayed_flag,'Y')='Y'
        -- and nvl(trunc(to_date(:parameter.lov_char_param1,'DD-MON-RRRR HH24:MI:SS')),trunc(sysdate)) between nvl(trunc(start_date),nvl(trunc(to_date(:parameter.lov_char_param1,'DD-MON-RRRR HH24:MI:SS')),trunc(sysdate)) ) and nvl(trunc(end_date),nvl(trunc(to_date(:parameter.lov_char_param1,'DD-MON-RRRR HH24:MI:SS')),trunc(sysdate)))
        -- and v.tax_code = :line.tax_Code ;
              and v.tax_rate = 0;
              */
                SELECT TAX_RATE_CODE
                  INTO V_TAX_CODE
                  FROM (SELECT DECODE( CREATED_BY, -1087, NVL( SUBSTRB( TAG, 1, 50 ), LOOKUP_CODE ), LOOKUP_CODE ) LOOKUP_CODE
                             , ENABLED_FLAG
                             , START_DATE_ACTIVE
                             , END_DATE_ACTIVE
                             , LOOKUP_TYPE
                             , LEAF_NODE
                          FROM FND_LOOKUP_VALUES
                         WHERE LANGUAGE = USERENV( 'LANG' )
                           AND LOOKUP_TYPE = 'ZX_OUTPUT_CLASSIFICATIONS'
                           AND SECURITY_GROUP_ID = 0
                           AND VIEW_APPLICATION_ID = 0) LKP
                     , ZX_ID_TCC_MAPPING_ALL TCC
                     , ZX_RATES_VL RVL
                 WHERE TCC.TAX_CLASSIFICATION_CODE = LKP.LOOKUP_CODE
                   AND TCC.TAX_RATE_CODE_ID = RVL.TAX_RATE_ID(+)
                   AND TCC.ACTIVE_FLAG = 'Y'
                   AND (TCC.TAX_CLASS = 'OUTPUT'
                     OR TCC.TAX_CLASS IS NULL)
                   AND TCC.ORG_ID = OUID
                   AND SYSDATE BETWEEN START_DATE_ACTIVE AND NVL( END_DATE_ACTIVE, SYSDATE )
                   AND RVL.PERCENTAGE_RATE = 0;
              EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                  V_TAX_CODE := '';
              END;

              COPY( V_TAX_CODE, 'line.tax_code' );
            END IF;
          END IF;
        ELSE
          V_LOCATION_CUST_ID := NAME_IN( 'order.INVOICE_TO_ORG_ID' );
          V_LOCATION_SHIP_ID := NAME_IN( 'order.SHIP_TO_ORG_ID' );

          BEGIN
            SELECT TAX_REFERENCE
              INTO V_TAX_REFERENCE
              FROM HZ_CUST_SITE_USES_ALL
             WHERE SITE_USE_ID = V_LOCATION_CUST_ID;
          EXCEPTION
            WHEN OTHERS
            THEN
              V_TAX_REFERENCE := NULL;
          END;

          BEGIN
            SELECT ATTRIBUTE24
              INTO V_FTZ
              FROM HZ_CUST_SITE_USES_ALL
             WHERE SITE_USE_ID = V_LOCATION_SHIP_ID;
          EXCEPTION
            WHEN OTHERS
            THEN
              V_FTZ := NULL;
          END;

          ---xxlib_gen.SHOW_MSG('1 :'||v_tax_reference||' 2:'||v_ftz||' 3:'||fnd_profile.value('EPM_FTZ_BRANCH')||' '||event);
          IF V_TAX_REFERENCE IS NULL
         AND NVL( V_FTZ, 'No' ) = 'No'
         AND FND_PROFILE.VALUE( 'EPM_FTZ_BRANCH' ) = 'Y'
         AND EVENT = 'PRE-BLOCK'
          THEN
            XXLIB_GEN.SHOW_MSG( 'Customer ini tidak mempunyai NPWP, SO Tidak bisa di BOOK' );
          ELSIF V_TAX_REFERENCE IS NULL
            AND NVL( V_FTZ, 'No' ) = 'No'
            AND FND_PROFILE.VALUE( 'EPM_FTZ_BRANCH' ) = 'Y'
            AND EVENT = 'BOOK'
          THEN
            XXLIB_GEN.SHOW_MSG( 'Customer ini tidak mempunyai NPWP, SO Tidak bisa di BOOK' );
            RAISE FORM_TRIGGER_FAILURE;
          END IF;
        END IF;
      END IF;
    END IF;
  END;

  --------------------------------------------------------------------
  PROCEDURE CHECKORDERDATE( EVENT VARCHAR2 )
  IS
    V_ORDER_DATE      DATE;
    V_ORDER_DATE_CHAR VARCHAR2( 25 );
    FORM_NAME         VARCHAR2( 30 ) := NAME_IN( 'system.current_form' );

    V_ATTRIBUTE6      VARCHAR2( 100 );
    V_ATTRIBUTE7      VARCHAR2( 100 );
    V_HEADER_ID       PLS_INTEGER;
    V_ORG_ID          PLS_INTEGER;
    V_COUNT           PLS_INTEGER;
  BEGIN
    --- null;

    --******************************************************
    -- Bambang - 01-APR-2013 - procedure tidak terpakai dimanfaatkan untuk
    -- RMA agar tidak menyentuh .fmb
    --******************************************************


    V_ATTRIBUTE7 := NAME_IN( 'order.attribute7' );

    IF V_ATTRIBUTE7 = 'AUTORMA'
    THEN
      V_ATTRIBUTE6 := NAME_IN( 'order.attribute6' );
      V_HEADER_ID := NAME_IN( 'order.header_id' );
      V_ORG_ID := NAME_IN( 'order.org_id' );

      SELECT COUNT( 1 )
        INTO V_COUNT
        FROM (  SELECT Z.INVENTORY_ITEM_ID, SUM( Z.OE_QTY ) OE_QTY, SUM( Z.RCV_QTY ) RCV_QTY
                  FROM (SELECT INVENTORY_ITEM_ID, ORDERED_QUANTITY OE_QTY, 0 RCV_QTY
                          FROM OE_ORDER_LINES_ALL
                         WHERE HEADER_ID = V_HEADER_ID
                        UNION ALL
                        SELECT B.ITEM_ID, 0 OE_QTY, NVL( B.QUANTITY, 0 ) RCV_QTY
                          FROM XXEPM.EPM_RMA_HEADERS A, XXEPM.EPM_RMA_LINES B
                         WHERE A.ORG_ID = V_ORG_ID
                           AND A.DOCUMENT_NUM = V_ATTRIBUTE6
                           AND A.HEADER_ID = B.HEADER_ID) Z
              GROUP BY Z.INVENTORY_ITEM_ID) ZZ
       WHERE NVL( OE_QTY, 0 ) <> NVL( RCV_QTY, 0 );

      IF V_COUNT > 0
      THEN
        XXLIB_GEN.SHOW_MSG( 'Qty RMA tidak sama dengan Qty Gudang!' );
        ---||' '||v_header_id||'-'||v_org_id||'-'||v_attribute6||'-'||v_attribute7,'ERROR');
        RAISE FORM_TRIGGER_FAILURE;
      END IF;
    END IF;
  --******************************************************


  /*
  if form_name in ('SSIOEORD','SSIOETEL','OEXOETEL','OEXOEORD') then
      v_order_date_char := name_in('order.ordered_date');
      v_order_date      := nvl( to_date(v_order_date_char,'DD-MON-RRRR HH24:MI:SS'), sysdate);

      if trunc(v_order_date) < trunc(sysdate) then
           xxlib_gen.SHOW_MSG('Order Date Sales Order tidak boleh lebih kecil dari tanggal sekarang','ERROR');
           raise form_trigger_failure;
      end if;
   end if;
   */
  END;

  --------------------------------------------------------------------
  PROCEDURE CHECKCUSTHOLD( V_RECORD_STATUS VARCHAR2 )
  IS
    V_PARTY_ID        HZ_PARTIES.PARTY_ID%TYPE;
    V_CUST_ACCOUNT_ID HZ_CUST_ACCOUNTS.CUST_ACCOUNT_ID%TYPE;
    V_SITE_USE_ID     HZ_CUST_SITE_USES_ALL.SITE_USE_ID%TYPE;
    V_CREDIT_HOLD     HZ_CUSTOMER_PROFILES.CREDIT_HOLD%TYPE DEFAULT NULL;
    FORM_NAME         VARCHAR2( 30 ) := NAME_IN( 'system.current_form' );
    BLOCK_NAME        VARCHAR2( 30 ) := NAME_IN( 'system.cursor_block' );
    V_HEADER_ID       PLS_INTEGER DEFAULT NULL;
  BEGIN
    IF FORM_NAME IN ('OEXOETEL', 'OEXOEORD')
    THEN
      IF V_RECORD_STATUS IN ('INSERT', 'NEW')
      THEN
        DECLARE
          V_LOCATION_CUST_ID VARCHAR2( 255 ) := NAME_IN( 'order.INVOICE_TO_ORG_ID' );
        BEGIN
          IF V_LOCATION_CUST_ID IS NOT NULL
          THEN
            BEGIN
              SELECT CREDIT_HOLD
                INTO V_CREDIT_HOLD
                FROM HZ_CUSTOMER_PROFILES
               WHERE SITE_USE_ID = V_LOCATION_CUST_ID;
            EXCEPTION
              WHEN OTHERS
              THEN
                NULL;
            END;

            IF NVL( V_CREDIT_HOLD, 'N' ) = 'Y'
            THEN
              XXLIB_GEN.SHOW_MSG( 'Customer ini memiliki giro tolak sehingga tidak diperkenankan membuat order baru', 'ERROR' );
              GO_BLOCK( 'ORDER' );
              RAISE FORM_TRIGGER_FAILURE;
            END IF;
          ELSE
            V_HEADER_ID := NAME_IN( 'order.header_ID' );

            IF NVL( V_HEADER_ID, 0 ) <> 0
            THEN
              XXLIB_GEN.SHOW_MSG( 'You must fill Bill to Location', 'ERROR' );
              GO_BLOCK( 'ORDER' );
              RAISE FORM_TRIGGER_FAILURE;
            END IF;
          END IF;
        END;
      END IF;
    END IF;
  END;

  -------------------------------------------------------------------------------------
  PROCEDURE UPDATEPRL( EVENT VARCHAR2 )
  IS
    V_COUNT                 PLS_INTEGER;
    V_PRINCIPAL             MTL_ITEM_CATEGORIES_V.SEGMENT5%TYPE;
    V_DIREKTORAT            MTL_ITEM_CATEGORIES_V.SEGMENT6%TYPE;
    V_LIST_HEADER_ID        EPM_KODE_SALUR.LIST_HEADER_ID%TYPE;
    V_BILL_TO_ID            HZ_CUST_ACCT_SITES_ALL.CUST_ACCT_SITE_ID%TYPE;
    V_PRODUCT_ATTR_VAL_DISP QP_LIST_LINES_V.PRODUCT_ATTR_VAL_DISP%TYPE;

    FORM_NAME               VARCHAR2( 30 ) := NAME_IN( 'system.current_form' );
    BLOCK_NAME              VARCHAR2( 30 ) := NAME_IN( 'system.cursor_block' );
    PARAM_TO_PASS1          PLS_INTEGER := NAME_IN( 'line.inventory_item_id' );
    PARAM_TO_PASS2          PLS_INTEGER := NAME_IN( 'order.salesrep_id' );
    V_LOCATION_CUST_ID      VARCHAR2( 255 ) := NAME_IN( 'order.INVOICE_TO_ORG_ID' );
    --bambang 6 nov 2006
    V_SOLD_TO_ORG_ID        VARCHAR2( 255 ) := NAME_IN( 'order.sold_to_org_id' );
    --bambang 6 nov 2006
    V_ORDER_DATE            DATE;
    V_ORDER_DATE_CHAR       VARCHAR2( 25 );
    V_HDR_PRICE_LIST        VARCHAR2( 16 ) := NAME_IN( 'order.PRICE_LIST' );

    V_N_ORG_ID              PLS_INTEGER := NAME_IN( 'ORDER.ORG_ID' );

    V_PRICE_LIST            VARCHAR2( 255 );
    V_PRICE_LIST_ID         VARCHAR2( 255 );
    V_UOM                   VARCHAR2( 255 );
    V_PRICE                 NUMBER;
    V_DB                    VARCHAR2( 50 );

    V_PZ_CODE               VARCHAR2( 2 );
    V_PZ_PRICE_LIST_ID      VARCHAR2( 255 );
  BEGIN
    IF FORM_NAME IN ('OEXOETEL', 'OEXOEORD')
    THEN
      V_ORDER_DATE_CHAR := NAME_IN( 'order.ordered_date' );
      V_ORDER_DATE := NVL( TO_DATE( V_ORDER_DATE_CHAR, 'DD-MON-RRRR HH24:MI:SS' ), SYSDATE );

      /*
     begin
       select operand, product_attr_val_disp
       into   v_price, v_product_attr_val_disp
       from   qp_list_lines_v
       where  product_id = param_to_pass1
       and   nvl(v_order_date, sysdate) between nvl(start_date_active,to_date('01-JAN-1950')) and nvl(end_date_active,to_date('01-JAN-3004'))
       and   list_header_id in (select list_header_id from qp_secu_list_headers_v where name = g_hna)
       and   start_date_active in (
            select max(start_date_active)
            from   qp_list_lines_v
            where  product_id = param_to_pass1
            and   nvl(v_order_date, sysdate) between nvl(start_date_active,to_date('01-JAN-1950')) and nvl(end_date_active,to_date('01-JAN-3004'))
            and   list_header_id in (select list_header_id from qp_secu_list_headers_v where name = g_hna)
           );
       copy(nvl(v_price,0), 'line.attribute15');
     exception when others then
       copy(0,'line.attribute15');
     end;
     */

      IF V_LOCATION_CUST_ID IS NOT NULL
      THEN
        SELECT DISTINCT LTRIM( RTRIM( CAT.SEGMENT5 ) )
          --,
          --ltrim(rtrim( CAT.segment6 ))
          INTO V_PRINCIPAL
          --,
          --v_direktorat -- per feb 16 by hengki
          FROM MTL_SYSTEM_ITEMS_B MST, MTL_ITEM_CATEGORIES_V CAT
         WHERE CAT.ORGANIZATION_ID = MST.ORGANIZATION_ID
           AND CAT.INVENTORY_ITEM_ID = MST.INVENTORY_ITEM_ID
           AND MST.INVENTORY_ITEM_ID = PARAM_TO_PASS1
           AND UPPER( CAT.CATEGORY_SET_NAME ) = 'INVENTORY'
           AND MST.ORGANIZATION_ID = V_N_ORG_ID;

        -- per feb 16 by hengki
        SELECT SEGMENT3
          INTO V_DIREKTORAT
          FROM EPM_SALES_DEPT_NEW_V
         WHERE SALESREP_ID = PARAM_TO_PASS2
           AND ORG_ID = V_N_ORG_ID;


        IF V_PRINCIPAL = 'NRDP'
        THEN
          BEGIN
            SELECT LIST_HEADER_ID
              INTO V_PRICE_LIST_ID
              FROM QP_LIST_LINES_V
             WHERE PRODUCT_ID = PARAM_TO_PASS1
               AND NVL( V_ORDER_DATE, SYSDATE ) BETWEEN NVL( START_DATE_ACTIVE, TO_DATE( '01-JAN-1950' ) )
                                                    AND NVL( END_DATE_ACTIVE, TO_DATE( '01-JAN-3004' ) )
               AND LIST_HEADER_ID IN (SELECT LIST_HEADER_ID
                                        FROM QP_SECU_LIST_HEADERS_V
                                       WHERE NAME = G_NRDP)
               AND START_DATE_ACTIVE IN
                     (SELECT MAX( START_DATE_ACTIVE )
                        FROM QP_LIST_LINES_V
                       WHERE PRODUCT_ID = PARAM_TO_PASS1
                         AND NVL( V_ORDER_DATE, SYSDATE ) BETWEEN NVL( START_DATE_ACTIVE, TO_DATE( '01-JAN-1950' ) )
                                                              AND NVL( END_DATE_ACTIVE, TO_DATE( '01-JAN-3004' ) )
                         AND LIST_HEADER_ID IN (SELECT LIST_HEADER_ID
                                                  FROM QP_SECU_LIST_HEADERS_V
                                                 WHERE NAME = G_NRDP));
          EXCEPTION
            WHEN OTHERS
            THEN
              XXLIB_GEN.SHOW_MSG( 'This item has principal ''NRDP'' but not found in ' || G_NRDP || ' price list', 'ERROR' );
              RAISE FORM_TRIGGER_FAILURE;
          END;

          COPY( V_PRICE_LIST_ID, 'line.Price_List_ID' );
          COPY( V_PRICE_LIST_ID, 'GLOBAL.LOV_RETURN_ITEM1' );
          COPY( G_NRDP, 'line.Price_List' );
          COPY( G_NRDP, 'line.Price_List_Mir' );
          COPY( G_NRDP, 'GLOBAL.LOV_RETURN_ITEM2' );

          OE_LINES.PRICE_LIST( 'WHEN-VALIDATE-ITEM' );
        ELSE
          IF V_SOLD_TO_ORG_ID IS NOT NULL
          THEN
            SELECT COUNT( * )
              INTO V_COUNT
              FROM EPM_KODE_SALUR
             WHERE SITE_USE_ID = V_LOCATION_CUST_ID
               AND CUSTOMER_ID = V_SOLD_TO_ORG_ID
               AND RTRIM( LTRIM( DIREKTORAT ) ) = V_DIREKTORAT
               AND RTRIM( LTRIM( PRINCIPAL ) ) = V_PRINCIPAL;
          ELSE
            SELECT COUNT( * )
              INTO V_COUNT
              FROM EPM_KODE_SALUR
             WHERE SITE_USE_ID = V_LOCATION_CUST_ID
               AND RTRIM( LTRIM( DIREKTORAT ) ) = V_DIREKTORAT
               AND RTRIM( LTRIM( PRINCIPAL ) ) = V_PRINCIPAL;
          END IF;

          IF NVL( V_COUNT, 0 ) > 0
          THEN
            IF V_SOLD_TO_ORG_ID IS NOT NULL
            THEN
              SELECT LIST_HEADER_ID
                INTO V_LIST_HEADER_ID
                FROM EPM_KODE_SALUR
               WHERE SITE_USE_ID = V_LOCATION_CUST_ID
                 AND CUSTOMER_ID = V_SOLD_TO_ORG_ID
                 AND RTRIM( LTRIM( DIREKTORAT ) ) = V_DIREKTORAT
                 AND RTRIM( LTRIM( PRINCIPAL ) ) = V_PRINCIPAL;
            ELSE
              SELECT LIST_HEADER_ID
                INTO V_LIST_HEADER_ID
                FROM EPM_KODE_SALUR
               WHERE SITE_USE_ID = V_LOCATION_CUST_ID
                 AND RTRIM( LTRIM( DIREKTORAT ) ) = V_DIREKTORAT
                 AND RTRIM( LTRIM( PRINCIPAL ) ) = V_PRINCIPAL;
            END IF;

            SELECT NAME, LIST_HEADER_ID
              INTO V_PRICE_LIST, V_PRICE_LIST_ID
              FROM QP_SECU_LIST_HEADERS_V
             WHERE LIST_HEADER_ID = V_LIST_HEADER_ID;


            COPY( V_PRICE_LIST_ID, 'line.Price_List_ID' );
            COPY( V_PRICE_LIST_ID, 'GLOBAL.LOV_RETURN_ITEM1' );
            COPY( V_PRICE_LIST, 'line.Price_List' );
            COPY( V_PRICE_LIST, 'line.Price_List_Mir' );
            COPY( V_PRICE_LIST, 'GLOBAL.LOV_RETURN_ITEM2' );

            OE_LINES.PRICE_LIST( 'WHEN-VALIDATE-ITEM' );
          END IF; --END IF XX_KODE_SALUR EXISTS
        END IF; --END IF NRDP
      END IF; --END IF LOCATION NOT NULL


      IF NAME_IN( 'line.Price_List_ID' ) /*v_price_list_id*/
                                         IS NOT NULL
      THEN
        V_PRICE_LIST_ID := NAME_IN( 'line.Price_List_ID' );
        V_PRICE_LIST := NAME_IN( 'line.Price_List' );

        /* Start Pricing Zone */
        IF SUBSTR( V_PRICE_LIST, 1, 1 ) = SUBSTR( V_PRICE_LIST, 3, 1 )
       AND NVL( V_PRINCIPAL, '~' ) <> 'NRDP'
        THEN
          BEGIN
            SELECT PZ_CODE
              INTO V_PZ_CODE
              FROM XXEPM.EPM_PZ_MATRIX
             WHERE ORG_ID = V_N_ORG_ID
               AND INVENTORY_ITEM_ID = PARAM_TO_PASS1;
          EXCEPTION
            WHEN OTHERS
            THEN
              V_PZ_CODE := '';
          END;

          IF V_PZ_CODE IS NOT NULL
          THEN
            BEGIN
              SELECT LIST_HEADER_ID
                INTO V_PZ_PRICE_LIST_ID
                FROM QP_SECU_LIST_HEADERS_V
               WHERE NAME = SUBSTR( V_PRICE_LIST, 1, 2 ) || V_PZ_CODE;

              V_PRICE_LIST_ID := V_PZ_PRICE_LIST_ID;
              V_PRICE_LIST := SUBSTR( V_PRICE_LIST, 1, 2 ) || V_PZ_CODE;
            EXCEPTION
              WHEN OTHERS
              THEN
                XXLIB_GEN.
                 SHOW_MSG( 'This item is in Price Zone but not found in ' || SUBSTR( V_PRICE_LIST, 1, 2 ) || V_PZ_CODE || ' price list', 'ERROR' );
                RAISE FORM_TRIGGER_FAILURE;
            END;
          END IF;
        END IF;

        /* End Pricing zone */

        COPY( V_PRICE_LIST_ID, 'line.Price_List_ID' );
        COPY( V_PRICE_LIST_ID, 'GLOBAL.LOV_RETURN_ITEM1' );
        COPY( V_PRICE_LIST, 'line.Price_List' );
        COPY( V_PRICE_LIST, 'line.Price_List_Mir' );
        COPY( V_PRICE_LIST, 'GLOBAL.LOV_RETURN_ITEM2' );

        OE_LINES.PRICE_LIST( 'WHEN-VALIDATE-ITEM' );
      END IF;
    END IF; --END IF FORM
  EXCEPTION
    WHEN OTHERS
    THEN
      RAISE;
  END;

  ---------------------------------------------------
  PROCEDURE ADJUST_OE( EVENT VARCHAR2 )
  IS
    V_HEADER_ID PLS_INTEGER DEFAULT NAME_IN( 'ORDER.header_id' );

    CURSOR CUR_ADJ IS
      SELECT ASS.RLTD_PRICE_ADJ_ID, ADJ.LIST_LINE_NO, ADJ.LINE_ID
        FROM OE_PRICE_ADJUSTMENTS ADJ, OE_PRICE_ADJ_ASSOCS ASS
       WHERE ADJ.PRICE_ADJUSTMENT_ID = ASS.PRICE_ADJUSTMENT_ID
         AND ADJ.LIST_LINE_TYPE_CODE = 'PRG'
         AND SUBSTR( ADJ.LIST_LINE_NO, 1, 2 ) IN ('S1', 'S2')
         AND ADJ.LINE_ID IN (SELECT LINE_ID
                               FROM OE_ORDER_LINES_ALL
                              WHERE HEADER_ID = V_HEADER_ID)
      UNION ALL
      SELECT ASS.RLTD_PRICE_ADJ_ID, ADJ.LIST_LINE_NO, ADJ.LINE_ID
        FROM OE_PRICE_ADJUSTMENTS ADJ, OE_PRICE_ADJ_ASSOCS ASS
       WHERE ADJ.PRICE_ADJUSTMENT_ID = ASS.PRICE_ADJUSTMENT_ID
         AND ADJ.LIST_LINE_TYPE_CODE IN ('OID', 'OPG')
         AND ADJ.LINE_ID IN (SELECT LINE_ID
                               FROM OE_ORDER_LINES_ALL
                              WHERE HEADER_ID = V_HEADER_ID);
  BEGIN
    IF V_HEADER_ID IS NOT NULL
    THEN
      FOR ADJ IN CUR_ADJ
      LOOP
        UPDATE OE_PRICE_ADJUSTMENTS
           SET LIST_LINE_NO = ADJ.LIST_LINE_NO
         WHERE PRICE_ADJUSTMENT_ID = ADJ.RLTD_PRICE_ADJ_ID;
      END LOOP;

      IF NOT FORM_SUCCESS
      THEN
        RAISE FORM_TRIGGER_FAILURE;
      END IF;
    END IF;
  /*
  XXLIB_ORD.adjust_oe('BOOK-ORDER');
  XXLIB_ORD.adjust_oe('POST-INSERT');
  XXLIB_ORD.adjust_oe('POST-UPDATE');
  */
  END;
---------------------------------------------------
END;