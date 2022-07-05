*** Settings ***
Documentation       Orders robots from RobotSpareBin Industries Inc.
...                 Saves the order HTML receipt as a PDF file.
...                 Saves the screenshot of the ordered robot.
...                 Embeds the screenshot of the robot to the PDF receipt.
...                 Creates ZIP archive of the receipts and the images.

Library             RPA.Browser.Selenium    auto_close=${FALSE}
Library             RPA.HTTP
Library             RPA.Tables
Library             String
Library             RPA.PDF
Library             RPA.Archive
Library             RPA.Dialogs
Library             RPA.Robocorp.Vault


*** Tasks ***
Order robots from RobotSpareBin Industries Inc
    Open the robot order website
    ${orders_csv_url}=    Get CSV URL
    ${orders}=    Get orders    ${orders_csv_url}
    FOR    ${row}    IN    @{orders}
        Close the annoying modal
        Fill the form    ${row}
        Preview the robot
        TRY
            Wait Until Keyword Succeeds    10x    0ms    Submit the order
        EXCEPT
            Refresh the website and re-fill the form    ${row}
            Submit the order
        END
        ${pdf}=    Store the receipt as a PDF file    ${row}[Order number]
        ${screenshot}=    Take a screenshot of the robot    ${row}[Order number]
        Embed the robot screenshot to the receipt PDF file    ${pdf}    ${screenshot}    ${row}[Order number]
        Go to order another robot
    END
    Create a ZIP file of the receipts
    [Teardown]    Close Browser


*** Keywords ***
Open the robot order website
    ${secret}=    Get Secret    secret_name=robot_orders_url
    Open Chrome Browser    ${secret}[url]
    Wait Until Page Contains Element    id:root

Close the annoying modal
    ${yep_button_css_selector}=    Set Variable
    ...    css:#root > div > div.modal > div > div > div > div > div > button.btn.btn-warning

    #If the yep button from the modal is visible
    ${is_element_visible}=    Is Element Visible    ${yep_button_css_selector}
    IF    ${is_element_visible}
        Click Button    ${yep_button_css_selector}
    ELSE
        Log    No modal visible to close.
    END

Get CSV URL
    Add heading    Provide Orders .csv URL
    Add text input    name=url_input
    ...    label=Orders .csv URL
    ...    placeholder=Please provide the orders .csv URL
    ...    rows=1
    ${result}=    Run dialog
    RETURN    ${result.url_input}

Get orders
    [Arguments]    ${orders_csv_url}
    Download    ${orders_csv_url}    overwrite=True
    ${out_orders}=    Read table from CSV    orders.csv    header=True
    RETURN    ${out_orders}

Fill the form
    [Arguments]    ${row}
    #Select the Head Type of the Robot
    Select From List By Index    id:head    ${row}[Head]

    #Select the Body Type of the Robot
    ${selector_body_radioButton}=    Set Variable    id:id-body-${row}[Body]
    Click Element    ${selector_body_radioButton}

    #Input the Legs Type
    Input Text    xpath://*[contains(@placeholder, 'legs')]    ${row}[Legs]

    #Input the Shipping Address
    Input Text    id:address    ${row}[Address]

Preview the robot
    Click Button    id:preview
    Wait Until Element Is Visible    id:robot-preview-image

Submit the order
    Click Button    id:order
    TRY
        Wait Until Element Is Visible    id:receipt
    EXCEPT    message
        Log    unable to order
    END

Go to order another robot
    Click Button    id:order-another
    Wait Until Page Contains Element    id:root

Refresh the website and re-fill the form
    [Arguments]    ${row}
    Close All Browsers
    Open the robot order website
    Close the annoying modal
    Fill the form    ${row}
    Preview the robot

Store the receipt as a PDF file
    [Arguments]    ${in_order_number}
    ${receipt_html}=    Get Element Attribute    id:receipt    outerHTML

    ${out_receipt_pdf_filename}=    Set Variable
    ...    ${TEMPDIR}${/}order_pdfs${/}orderReceipt${in_order_number}.pdf

    Html To Pdf    ${receipt_html}    ${out_receipt_pdf_filename}

    RETURN    ${out_receipt_pdf_filename}

Take a screenshot of the robot
    [Arguments]    ${in_order_number}

    ${out_robot_screenshot_filename}=    Set Variable
    ...    ${TEMPDIR}${/}robotImages${/}robot${in_order_number}

    Wait Until Element Is Visible    id:robot-preview-image
    Screenshot    id:robot-preview-image    ${out_robot_screenshot_filename}.png
    Sleep    time_=1000ms

    RETURN    ${out_robot_screenshot_filename}.png

Embed the robot screenshot to the receipt PDF file
    [Arguments]    ${in_pdf}    ${in_screenshot}    ${in_order_number}
    ${files_list}=    Create List    ${in_pdf}    ${in_screenshot}

    Add Files To Pdf    ${files_list}    ${in_pdf}

Create a ZIP file of the receipts
    Archive Folder With Zip    ${TEMPDIR}${/}order_pdfs${/}    ${OUTPUT_DIR}${/}robot_orders.zip

Close Browser
    Close All Browsers
