public with sharing class AccountSelector {
    public static List<Account> selectByIds(Set<Id> setAccountIds) {
        if (setAccountIds == null || setAccountIds.isEmpty()) {
            return new List<Account>();
        }

        return [
            SELECT Id, Description
            FROM Account
            WHERE Id IN :setAccountIds
            WITH USER_MODE
        ];
    }
}
