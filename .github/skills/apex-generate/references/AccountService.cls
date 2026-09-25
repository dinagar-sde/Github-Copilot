public with sharing class AccountService {
    public static void markReviewed(Set<Id> setAccountIds) {
        if (setAccountIds == null || setAccountIds.isEmpty()) {
            return;
        }

        List<Account> listAccounts = AccountSelector.selectByIds(setAccountIds);
        for (Account account : listAccounts) {
            account.Description = 'Reviewed';
        }

        if (!listAccounts.isEmpty()) {
            update listAccounts;
        }
    }
}
