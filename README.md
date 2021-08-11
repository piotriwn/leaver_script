# leaver_script
Powershell 2 script - handling bulk AD user leavers

HOW TO

	1. Make sure you have opened the ticket, attachments if present.
	2. Prepare input file. It's called input.csv. You have 3 fields to consider. Remember, you may add as many users as you'd like (Company column) - that's the idea!  
		a. Under Company please paste Company AD user number of the account to be disabled  
		b. Under TransferTo please paste Company AD user number of the account to which existing dependencies should be transferred. Leave blank if not specified in the request.  
		c. Under Odrive please paste number of days after which Odrive shall be deleted. Leave blank to set to default - 30 days.  
	3. Open Powershell, paste the command cd "bulk_leaver"
	4. Then paste command .\leaver_script.ps1 
	5. You will have to fill in the (1) ticket number, (2) whether you want to check dependencies [d] or action the ticket [l]
	6. Choosing "d" will only check dependencies and prepare console as well as file output.
	7. Choosing "l" will action the ticket - disable account, transfer dependencies and more. List at the end of this article.
	8. Examine file output in "Results" folder. Check for any errors, identify their cause. Amend them if possible.
	9. Open relevant log file and paste the lines related to Odrive to ticket worknotes.


What this script does:
1) Checks dependencies.
2) Validates input.csv - to check if data does not contain any syntactic errors.
3) Identifies error if TransferTo field is empty while dependencies are present. Outputs relevant information.
4) Reassigns managers.
5) Reassigns group membership.
6) Disables account.
7) Removes any groups other than "Domain users".
8) Changes account description.
9) Moves account to Leavers OU.
10) Checks if account has been properly disabled - don't worry the checks are real, it does not simply output its own data, but again uses get- Powershell cmdlets to establish if all is correct.
11) Outputs lines which should later be copied to ticket's worknotes (info concerning Odrive).

