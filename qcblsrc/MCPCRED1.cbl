       IDENTIFICATION DIVISION.
       PROGRAM-ID. MCPCRED1.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-MONTHLY-RATE       PIC 9(3)V9(9) COMP-3 VALUE ZERO.
       01 WS-FACTOR             PIC 9(3)V9(9) COMP-3 VALUE ZERO.

       LINKAGE SECTION.
       01 LK-REQUEST.
          05 LK-AMOUNT          PIC 9(11)V99 COMP-3.
          05 LK-TERM-MONTHS     PIC 9(3) COMP-3.
          05 LK-ANNUAL-RATE     PIC 9(3)V9(6) COMP-3.

       01 LK-RESPONSE.
          05 LK-RETURN-CODE     PIC X(7).
          05 LK-MONTHLY-PAYMENT PIC 9(11)V99 COMP-3.
          05 LK-TOTAL-PAYMENT   PIC 9(13)V99 COMP-3.
          05 LK-DESCRIPTION     PIC X(250).

       PROCEDURE DIVISION USING LK-REQUEST LK-RESPONSE.

           INITIALIZE LK-RESPONSE

           IF LK-AMOUNT <= ZERO
              MOVE 'MCP0400' TO LK-RETURN-CODE
              MOVE 'El monto debe ser mayor que cero'
                TO LK-DESCRIPTION
              GOBACK
           END-IF

           IF LK-TERM-MONTHS <= ZERO
              MOVE 'MCP0400' TO LK-RETURN-CODE
              MOVE 'El plazo debe ser mayor que cero'
                TO LK-DESCRIPTION
              GOBACK
           END-IF

           *> Cálculo demostrativo simple (interés lineal), no financiero oficial.
           COMPUTE LK-TOTAL-PAYMENT =
             LK-AMOUNT +
             (LK-AMOUNT * (LK-ANNUAL-RATE / 100) *
              (LK-TERM-MONTHS / 12))

           COMPUTE LK-MONTHLY-PAYMENT =
             LK-TOTAL-PAYMENT / LK-TERM-MONTHS

           MOVE 'MCP0000' TO LK-RETURN-CODE
           MOVE 'Simulación demostrativa completada'
             TO LK-DESCRIPTION

           GOBACK.
